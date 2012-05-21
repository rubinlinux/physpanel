#!/usr/local/bin/perl
# :vim:expandtab ts=4 sw=4:
use strict;
use warnings;
use CGI;
use Data::Dumper;

use Monitoring::Livestatus;
my $q = CGI->new;
$Data::Dumper::Sortkeys = 1;

print $q->header('text/html');

my $service_table = [];

sub query_live_status {
    my $service_table = shift;
    my $ml = Monitoring::Livestatus->new(
       errors_are_fatal => 0,
       socket => '/usr/local/var/nagios/livestatus.sock',
    );

    my $host_services = $ml->selectall_arrayref("GET services\nFilter: host_groups >= important", {Slice => {} });

    foreach my $service (@$host_services) {
        add_service_row($service_table, $service)
    }
}

sub add_service_row {
   my ($service_table, $service) = @_;

   my $row = {};
   foreach my $field (qw/host_name description host_plugin_output plugin_output host_acknowledged acknowledged groups check_command host_check_command host_address host_groups host_state is_flapping host_is_flapping last_state_change last_time_critical last_time_ok last_time_warning last_time_unknown next_check state/) {
      $row->{$field} = $service->{$field};
   }
   return if(service_in_group($row, "notinlights"));
   push @$service_table, $row;
}

sub service_in_group {
    my $s = shift;
    my $g = shift;
	my @groups = @{$s->{groups}};
	foreach my $group (@groups) {
		if($group eq $g) {
		return 1;
		}
	}
    return 0;
}

# Re-map the states into a sort order we like
my %state_sort = (
    "0" => 0,   # ok
    "1" => 1,   # warning
    "2" => 2,   # critical
    "3" => 0.5, # unknown
    "4" => 4,
);

sub servicesort {
    #print "DEBUG: ". ($a->{state} <=> $b->{state}). "\n";
    my $res = 0;

    $res = ($state_sort{$b->{state}} <=> $state_sort{$a->{state}}) unless $res != 0;
    #$res = service_in_group($b, 'critical') <=> service_in_group($a, 'critical') unless $res != 0;
    #$res = $a->{description} <=> $b->{description} unless $res != 0;

    return $res;
}

sub get_state_human {
    my $service = shift;
    if($service->{'in_downtime'}) {
		return "DOWNTIME";
    }
    if($service->{'is_acknowledged'}) {
        return "ACKNOWLEDGED";
    }
    if($service->{'state'} == 0) {
		return "OK";
    }
    if($service->{'state'} == 1) {
		return "WARNING";
    }

    if($service->{'state'} == 2) {
		return "CRITICAL";
    }

    if($service->{'state'} == 3) {
		return "UNKNOWN";
    }
}

sub get_warning_color {
    my $service = shift;

    return "#0F0" if($service->{state} == 0);
    return "#FF0" if($service->{state} == 1);
    return "#F80" if($service->{state} == 2);
    return "#F80" if($service->{state} == 3);
     
    return "#FFF";
}

###
## BEGIN
###

query_live_status($service_table);

my @sorted_service_table = sort servicesort @$service_table;

my $info = "";
    #$info .= "<div class=\"alert_box\" style=\"background:".get_warning_color($s).";\"></div>";
    $info .= '
        <table class="host_table">
        <tr><th>Host</th><th>Service</th><th>Details</th></tr>
    ';
foreach my $s (@sorted_service_table) {
    $info .= '<tr class="host_row_'. ( (service_in_group($s, 'critical') && $s->{state} > 0)?"ISCRITICAL":get_state_human($s) ). '">';
    $info .= '<td valign="top" nowrap>';
    $info .=   '<span class="hostname">'. $s->{host_name}.'</span><br />';
    $info .=   '<span class="nagios_time">TIMESTAMP</span><br />';
    $info .= '</td>';
    $info .= '<td valign="top">';
    $info .= '<a class="subtle" href="https://nagios.physics.umn.edu/nagios/cgi-bin/extinfo.cgi?type=2&host='. $s->{'host_name'}.'&service='. $s->{description} . '" target="_blank">';
    $info .= $s->{description};
    $info .= '</a></td>';

    $info .='<td valign="top">';
    $info .=$s->{plugin_output};
    $info .='</td>';

#    $info .= "DEBUG: showing ".(service_in_group($s, 'critical')?"CRITICAL":"") ." service ". $s->{host_name}. " - ". $s->{description}."\n";
#    $info .= "DEBUG:    State: ". get_state_human($s) . " - ". $s->{plugin_output}. "\n";
    #print Dumper($s);
    #$info .= "</div>\n\n";
    $info .= "</tr>";
}
$info .= '</table>';

my $css = "
    <style type=\"text/css\">
        body {
            background: #559;
        }
        table.host_table {
            border: 1px solid black;
            width: 100%;
            padding: 0px; margin: 0px;
            background: white;
        }
        table.host_table th {
            background: black; color: white; font-weight: bold;
        }
        table.host_table td {
            padding: 0px; margin: 0px;
            padding-left: 4px;
            padding-right: 4px;
            font-size: 1.4em;
        }
        table.host_table tr {
            border: 1px solid black;
        }
        .host_row_DOWN {
                background: #F80;
                color: black;
        }
        .host_row_UP {
            background: #0F0; color: black;
        }
        .host_row_OK { /* OK */
            background: #0F0; color: black;
        }
        .host_row_WARNING { /* warning */
            background: #dcdc00; color: black;
        }
        .host_row_OUTAGE { /* outage */
            background: #F80; color: black;
        }
        .host_row_UNKNOWN { /* unknown service */
            background: #F88; color: black;
        }
        .host_row_CRITICAL { /* critical service state (not a critical service) */
            background: #f80; color: black;
        }
        .host_row_ISCRITICAL { /* critical service state on a service in the critical group */
            background: #f00; color: black;
        }
        .host_row_ACKNOWLEDGED { /* critical service */
            background: #C99; color: black;
        }
        .host_row_DOWNTIME { /* critical service */
            background: #696; color: black;
        }
        .hostname {
                font-family: sans-serif;
                font-weight: bold;
        }
        div.alert_box {
            font-size: 2.8em; font-weight: bold; color: black;
            border: 1px solid black;
            padding: 10px; margin: 5px;
            background: #559;
            margin-left: 0;
            margin-right: 0;
        }
        div.datetime_box {
            font-size: 1.8em; font-weight: bold; color: black;
            border: 1px solid black;
            background: #226;
            color: white;
        }
        #datetime {
           padding: 10px; margin: 5px;
           margin-left: 0; margin-right: 0;
           width: 29%;
           white-space: nowrap;
        }
        a:link.subtle, a:visited.subtle {
            color: black;
            text-decoration: none;
        }
        a:hover.subtle {
            text-decoration: underline;
        }
        span.nagios_time {
            font-size: 0.6em;
        }
        #specials {
                float: right;
                font-size: 20px;
                width: 65%;
                xxxtext-align: right;
                padding: 5px;
        }
        #outhosts {
            font-weight: normal;
            font-family: sans-serif;
        }

     </style>
";

print "
    <html>
       <head><title>Phys Panel</title>
	<meta http-equiv=\"refresh\" content=\"60\">
        $css
       </head>
<body>
<table id=\"bigtable\" width=\"100%\" cellspacing=0 cellpadding=0>
<tr>
  <td valign=\"top\" width=\"100%\">
    <div class=\"datetime_box\">
      <div id=\"specials\">SPECIALS</div>
      <div id=\"datetime\">DATE</div>
    </div>
    <div class=\"outagelist\">$info</div>
  </td>
</tr>
</table>

</body>
</html>
";

print CGI::escapeHTML("mod_perl <rules>!\n");

#print Dumper($services);

# Hostname, Service description, service details
# timestamp, 



package UMPhysPanel::Mason;

# Bring in Mason objects
use HTML::Mason;

# Always "use strict" in mod_perl
use strict;

# Force warnings/dies to dump backtrace
#use Carp::Always;

{
package HTML::Mason::Commands;
use vars qw(%session);
use Fcntl;
use IO::File;
use IO::Handle;
use URI::Escape;
use File::Spec;
use File::Copy;
use File::Find;
use File::stat;
use Text::Wrap;
use Date::Format;
use Date::Language;
use LWP::MediaTypes qw(guess_media_type);
use IPC::Run;
# needed for new Mason caching...?
use Cache::Cache;
# the rest are additional/local
use Date::Calc qw(:all);
use HTML::Entities;
use Net::SSLeay;
use IO::Socket::SSL;
use IPC::Open2;
use Apache2::Request;
use Apache2::Upload;
use Apache2::Cookie;
use Apache2::URI;
use DBI;
use Apache2::Const;
use Apache2::RequestUtil;
use Apache2::Connection ();
use Apache2::ServerRec();
use Apache2::ServerUtil ();
use Convert::ASN1;
use APR::Table;
use APR::Pool ();
use Data::Dumper;
#use physdb;
use Carp qw/carp cluck confess croak/;
# Our mason helper functions like _h and _u
#use MasonHelper;
}


# http://www.masonhq.com/docs/manual/Interp.html for docs on this
my %ah;
my $comproot;
my $site = 'physpanel';

# So, this top bit of code is executed once for each new thread of apache that is spawned. It has general setup.

$comproot = '/export/data/nagios/physpanel/';
warn("This is the perl post config handler thingy");

# This handler is called back for each request.
sub handler
{
    warn("The handler is being called");
    # Get the Apache request object
    my ($r) = @_;
    my $port = $r->get_server_port();

    my $randseed = 384237853721111;
    srand(time + $randseed + $$);

    # Only handle certain types of request (text, html etc); also handle downloads directory (for dhandler)
    return -1 if ($r->uri =~ /^\/images/) || ($r->content_type && $r->content_type !~ m|^text/|i && $r->uri == '/') 
                 || ($r->filename && ($r->filename =~ m/\.(css|txt|js)$/i ));

    # Determine instance-specific comproot and mason-data locations
    my $this_comproot = $comproot;
    my $data_dir = "/export/data/nagios/mason-data";
    my %debug = (
            named_component_subs => 1,
            static_source => 0,
            code_cache_max_size => 0,
            use_object_files => 0,
        );

    my $documentroot = $this_comproot;
    $r->document_root($documentroot);

    # Now look for an apache handler matching our conditions (port etc). If not found, this is our first
    # request of this child fork. So create one.
    if(!defined $ah{$site}) {
        $ah{$site} = HTML::Mason::ApacheHandler->new(
            comp_root => $this_comproot,
            data_dir => $data_dir,
            args_method => 'mod_perl',
            allow_globals => ['$dbh', '$shopdb'],
            error_mode => 'fatal',
            static_source => 1,
            static_source_touch_file => "$data_dir/reload_source",
            %debug,
        ); # we trap the error ourselves at the bottom
    }

    # Now here wa actually handle the request, using the handler we
    # found/created above. Its eval'd so we can intercept the error.
    my $status = eval  { $ah{$site}->handle_request($r) };
    my $err = $@;

    # The untie statement signals Apache::Session to write any
    # unsaved changes to disk.
    untie %HTML::Mason::Commands::session;

    # error handler...
    if ($err || ($status >= 500 && $status < 600)) {
        $r->pnotes( error => $err );
        my $status_file = defined($status) ? $status : '500';
        if ($r->headers_in->{'Accept'} =~ m'text/javascript') {
            $status_file .= '_ajax';
        }
        my $errh = $documentroot . '/errors/' . $status_file . '.html';
        if (!$err && (-e $errh)) {
            $r->filename($errh);
        } 
        else {
            if ($r->headers_in->{'Accept'} =~ m'text/javascript') {
                $r->filename($documentroot . '/errors/500_ajax.html');
            } 
            else {
                $r->filename($documentroot . '/errors/500.html');
            }
        }
        my $errstatus = eval { $ah{$site}->handle_request($r) };
            warn ("Found site $site: Displaying staging error ". (defined $errstatus?$errstatus:"(undef)"). " page\n");
            my $errerr = $@;
            if($errerr) {
                # Things are SO broken that the standard template error page can't even display. So just print the error
                # here without a wrapper so at least it can be seen.
                #print("echo Staging Goooo! site: $site<br> comproot: $this_comproot<br> data_dir: $data_dir<br>" . $documentroot);
                print "<h1>Error</h1> There was an error, and /errors/500.html also encountered an error! The error preventing the error handler page from executing is displayed below:";
                my $err_details = $errerr;
                print $err_details->as_html();
                print "<h4>headers:</h4><pre>";
                print Dumper($r->headers_in);
                print "</pre>";
                return($errstatus);
            }
            else {
                # error page executed successfully.
                return $errstatus;
            }
    }
    return $status;
}

1;

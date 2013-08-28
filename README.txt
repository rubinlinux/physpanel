 ####
 # Physpanel - Nagios live status screen
 # Written in Perl/Mason
 ###

 I wrote this to run on a monitor we hung on the wall in the IT room. It shows the current
 state of things with all the garbage filtered out, on one screen, ranked by order of importance.
 
 The display updates itself via ajax/javascript and lets you know at a glance if something is wrong.

 There are 2 parts:
   On the blue area at the top, the current time is shown (so you can see easily if the display
   is stale) and services which are in the 'special' servicegroup are broken out and handled here
   by your custom perl rules. We use this to take things which are frequently in a non-OK state and
   sumerise them up top, so they don't fill up the board. 

   The next section is a list of all services whose state changed recently, ranked by their severity.
   The ranking uses some huristics to show the things that really matter at the top.
     * First, servicegroup 'critical' services which are in a critical state show at the top (and in red)
     * Then, items are ranked by their criticality (Critical, Warning, Unknown)
     * Finally, hosts/services in 'downtime' are shown in dark green, then acknowledged outages, and OK

 - Requirements -

   * nagios
   * mk_livestatus (Live nagios query plugin)
   * apache 
   * mod_perl
   * mason
   * Date::Calc
   * DBI
   * Convert::ASN1
   * Time::Duration
   * Monitoring::Livestatus



package Bot::BasicBot::Pluggable::Module::Traffic;

use strict;
use warnings;
use LWP::Simple "get";
use Time::Local "timelocal";

use Bot::BasicBot::Pluggable::Module;
BEGIN { our @ISA = qw(Bot::BasicBot::Pluggable::Module); }

sub _get_incidents {
    my ($explicit) = @_;

    # TODO: If-Modified-Since
    my $report = get("http://www.wsdot.wa.gov/traffic/seattle/incidents/");

    ($report) = $report =~ m:Seattle Area Incidents</span></h2>\s+<p><p>(.*?)</p>(?!<p>):s
        or return "traffic parse error: incidents not found";

    my @incidents = grep length, split m!</p>\s*<p>\s*!, $report;

    shift @incidents while @incidents && grep $incidents[0] =~ $_,
        qr/^Seattle Area -/,
        qr/^INCIDENT INFORMATION /,
        qr/^Current Operator ?:/,
        qr/^Northwest Region Traffic Systems Management Center, WSDOT/;

    if ($explicit) {
        for (@incidents) {
            for my $swap ( _get_swaps() ) {
                s/$swap->{'pattern'}/$swap->{'replacement'}/g
            }
        }
    }

    @incidents = "No incidents." if ! @incidents;

    return join "\n", @incidents;
}

sub _next_alert {
    my $time = shift() || time();

    # get date 6h45m1s hence
    my ($mday, $mon, $year, $wday) = (localtime($time + 6*3600 + 45*60 + 1))[3..6];

    # alert at 17:15:00 on that day
    my $next = timelocal(0, 15, 17, $mday, $mon, $year);
    # but no alerts on weekends
    $next = _next_alert($next) if $wday == 0 || $wday == 6;

    return $next;
}

sub said {
    my ($self, $mess, $pri) = @_;
    return if $pri != 2;

    my $body = $mess->{body};
    return if $body !~ /^traffic\b/;

    _get_incidents(1);
}

my $next_alert = _next_alert();
sub tick {
    my $self = shift;
    return if time() < $next_alert;
    $next_alert = _next_alert();

    $self->say(channel => "#spqr", body => _get_incidents());
    return;
}

sub help {
    return "Commands: 'traffic'";
}

{
    my @swaps = (
        # pattern, replacement, exact only
        [ q/\bblocking\b/, 'blogging', ],
        [ q/\bplan accordingly\b/, 'play accordion', ],
        [ q/\broadwork\b/, 'men at work', ],
        [ q/\bmaintenance\b/, 'men at work', ],
        [ q/\bverified with camera\b/, 'verified with Gamera' ],
    );

    sub _get_swaps {
        return map {
            ( +{ 'pattern' => qr/$_->[0]/ , 'replacement' => $_->[1]  },
                $_->[2]  # special "exact" flag
                    ? () # empty list
                    : +{ 'pattern' => qr/$_->[0]/i, 'replacement' => uc($_->[1]) },
            )
        } @swaps;
    }
}
1;

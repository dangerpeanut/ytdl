#!/usr/local/bin/perl
#===============================================================================
#
#         FILE:  ytdl.pl
#
#        USAGE:  ./ytdl.pl
#
#  DESCRIPTION: A perl daemon that wraps youtube-dl for unattended downloading of url lists.
#
#      OPTIONS:  -a -t -d
# REQUIREMENTS:  Youtube-dl https://rg3.github.io/youtube-dl/
#                IO::Compress::Gzip http://search.cpan.org/~pmqs/IO-Compress-2.074/lib/IO/Compress/Gzip.pm
#                File::Copy
#                Getopt::Long
#                Data::Validate::URI
#                Config::Simple
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Peanut Danger (admin), dangerpeanut.net@gmail.com
#      COMPANY:  Dangerpeanut.net
#      VERSION:  1.0
#      CREATED:  03/26/17 13:40:05
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;

use feature qw/say/;

use File::Copy qw/move/;

use Getopt::Long;

use IO::Compress::Gzip qw/gzip $GzipError/;

use Data::Validate::URI qw/is_uri/;

use Config::Simple;

#For the love of god, please change the config

my $cfg = new Config::Simple('ytdl.ini');

my $disablescript = 'true'; #This line is important

my $add = 0;
my $daemon= 0;
my $test = 0;
my $quit = 0;
my $interrupted = 0;

$SIG{INT} = sub{ $quit = 1; $interrupted = 1; say '' };


GetOptions ('a' => \$add,
            't'   => \$test,
            'd'   => \$daemon);

sub startup{
    if ($disablescript eq 'true'){
    die "User did not configure the script." if ($disablescript eq 'true');
    }

    $cfg->param('option.epoch', time);

    if ($test == 1){
        testing();
    };

    if ( -s $cfg->param('files.list')){
        printlist();
    } else {
        say "No files in list to print.";
    }

    if ($add){
        addlist();
        printlist();
        exit;
    }
    if ($daemon){
        daemonize();
    }


    mainloop();
};

sub mainloop{
    until($quit == 1){
    checklogsize();
        if (-s $cfg->param('files.list')){
            getvids();
        };
        takeanap();

}

};

sub getlist{
#    open (my $fh, '<', $cfg->param('files.list')) or die "Can't open $cfg->param('files.list')";
    open (my $fh, '<', $cfg->param('files.list'))
        or die "Can't open $cfg->param('files.list')";
    chomp(my @links = <$fh>);
    close $fh;
    return \@links;
};

sub printlist{
    say "Printing file list.";
    print "\n\n";
    open (my $fh, '<', $cfg->param('files.list'))
        or die "Can't open $cfg->param('files.list')";
    chomp(my @links = <$fh>);
    close $fh;
    foreach my $url (@links){
        say $url;
    };
};


sub clearlist{
    say "Backing up current list file.";
    open (my $fh, '<', $cfg->param('files.list'))
        or die "Can't open $cfg->param('files.list')";
    open (my $tfh, '>', $cfg->param('files.tmplist'))
        or die "Can't open $cfg->param('files.list')";
    print $tfh $fh;
    say "Clearing current list file.";
    open ($fh, '>', $cfg->param('files.list'))
        or die "Can't open $cfg->param('files.list')";
#    print $fh, '';
    close $fh;
    close $tfh;
    say "List file cleared.";
};

sub clearlog{
    open (my $fh, '>', $cfg->param('files.log'))
        or die "Can't open $cfg->param('files.log')";
    close $fh;
};

sub daemonize{
    say "Dropping into background.";
    say "Please see $cfg->param('files.log') later.";
    open(STDIN, '</dev/null');
    open(STDOUT, '>>', $cfg->param('files.log'));
    open(STDERR, ">&STDOUT");

}

sub resetoutput{
    open(STDOUT, '>>', $cfg->param('files.log'));

}

sub addlist{
    die "No links given." unless ($ARGV[0]);
    open (my $fh, '>>', $cfg->param('files.list'))
        or die "Can't open $cfg->param('files.list')";
    foreach my $url (@ARGV){
        say "$url is not a valid link" & next unless (is_uri($url));
        say "Adding $url to queue...";
        say $fh $url;
    }
    close $fh;
};

sub getvids{
#    chdir $cfg->param('dirs.tmp');
    my @cmds;
    my $output = $cfg->param('dirs.done') . $cfg->param('option.ytdlouttemp');
    my $vids = getlist();
    if ($test == 0){
        clearlist();
    }
    push @cmds, 'nohup' if ($daemon == 1 );
    push @cmds, '/usr/local/bin/youtube-dl';
    if ($test == 1){
        push @cmds, '--simulate';
    }
    push @cmds, (
        '-r',"$cfg->param('option.rate')",
        '--yes-playlist',
        '-o', "$output",
        '--no-progress',
        '--write-description',
        '--write-info-json',
        '--ignore-errors',
        #'--option',
        # @{ $vids } # Insert custom youtube-dl options above this line
    );
    foreach my $vid (@{ $vids }) {
    system(@cmds, $vid) == 0 or say "Download of $vid failed: $?";
#    movefinished();
}
};

sub takeanap{
    say "Nothing to do. Sleeping for $cfg->param('option.naptime') seconds." unless($daemon == 1);
    my $timer = $cfg->param('option.naptime');
        print "+++ seconds left\r" unless($daemon == 1);
    until ( $timer == 0 or $quit == 1 ){
        print "$timer\n" unless($daemon == 1);
        --$timer;
        sleep 1;
}
say '';
};



sub END{
#sub quitting{
    die "User sent interrupt." if ($interrupted == 1);
    exit 0;

};

sub rotatelog{
    say "Beginning Log Rotation";
    my @times = getdate();
    my $logfile = $cfg->param('dirs.logs') . $times[0] . '-' . $times[1] . '-' . ".ytdl.log.gz";
    say "Log is being rotated into $logfile";
    open(STDOUT, '>>', $cfg->param('files.tmplog'));
    open (my $fh, '<', $cfg->param('files.log')) or die "Can't open $cfg->param('files.log'): $?";
    my $zip = new IO::Compress::Gzip $logfile or say "gzip failed: $GzipError";
    local $/ = undef;
    my $data = <$fh>;
    close $fh;
#    print $zip $fh;
    $zip->print($data);
    close $zip;
    clearlog();
    resetoutput();
};


sub testing{
    my @times = getdate();
    print "Date: $times[0]\nTime: $times[1]\nEpoch: $times[2]\n";
};


sub getdate{
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
    $year += 1900;
    my @months = qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
    my $date = $months[$mon] . '-' . $mday . '-' . $year;
    my $time = $hour . ':' . $min . ':' . $sec;
    my $epoch = time;
    $hour = ( $hour % 12 ) if ( $hour > 12 );
    return ($date, $time, $epoch);

};

sub getfilesize{
    my $file = shift;
    my @stat = stat $file;
    return $stat[7];
};

sub checklogsize{
    my $logsize = getfilesize($cfg->param('files.log'))
        or say "Cannot open file $cfg->param('files.log'): $?";
    if ( $logsize > $cfg->param('option.rotatesize')){
        say "Log file is too large! Beginning log rotation.";
        rotatelog();
    } else {
        my @times = getdate();
        say "beep boop\n $times[0]\t$times[1]\n";
#        say "Log file size: $logsize bytes."
    };
};

startup();

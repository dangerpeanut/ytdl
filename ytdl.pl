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
#                IO::Compress::Gzip
#                File::Copy
#                Getopt::Long
#                Data::Validate::URI
#                Config::Tiny
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

use Env qw/HOME/;

use File::Copy qw/move copy/;

use Getopt::Long;

use IO::Compress::Gzip qw/gzip $GzipError/;

use Data::Validate::URI qw/is_uri/;

use Config::Tiny;

my $disablescript = 'true'; #This line is important

#For the love of god, please change the config

my $cfg = Config::Tiny->new;

$cfg = Config::Tiny->read("$HOME/.ytdl.ini");

# Setting some simple options

my $add = 0;
my $daemon= 0;
my $test = 0;
my $quit = 0;
my $interrupted = 0;

# Sets $quit to true if it receives the INT signal.

$SIG{INT} = sub{ $quit = 1; $interrupted = 1; say '' };

$SIG{HUP} = \&catch_hup;

GetOptions ('a' => \$add,
            't'   => \$test,
            'd'   => \$daemon);

sub startup{
    if ($disablescript eq 'true'){
    die "User did not configure the script." if ($disablescript eq 'true');
    }

    if ($test == 1){
        testing();
    };

    if ( -s $cfg->{'files'}->{'list'} ){
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

    #loops until SIGINT

    until($quit == 1){

    #See if the log is too big

    checklogsize();

        #If the list file has content, then we start downloading videos.

        if (-s $cfg->{'files'}->{'list'}){
            getvids();
        };

        # If the list file is empty, then we take a nap.

        takeanap();

        #End Loop
}

};

# Returns a list of urls from the file.

sub getlist{
#    open (my $fh, '<', $cfg->{'files'}->{'list'}) or die "Can't open $cfg->{'files'}->{'list'}";
    open (my $fh, '<', $cfg->{'files'}->{'list'})
        or die "Can't open $cfg->{'files'}->{'list'}";
    chomp(my @links = <$fh>);
    close $fh;
    return \@links;
};

# Prints the current working list file.

sub printlist{
    say "Printing file list.";
    print "\n\n";
    open (my $fh, '<', $cfg->{'files'}->{'list'})
        or die "Can't open $cfg->{'files'}->{'list'}";
    chomp(my @links = <$fh>);
    close $fh;
    foreach my $url (@links){
        say $url;
    };
};


# Copies the working list to the temp list and empties the working list.

sub clearlist{
    my $fh;
    say "Backing up current list file.";
    copy($cfg->{'files'}->{'list'}, $cfg->{'files'}->{'tmplist'});
    say "Clearing current list file.";
    open ($fh, '>', $cfg->{'files'}->{'list'})
        or die "Can't open $cfg->{'files'}->{'list'}";
    close $fh;
    say "List file cleared.";
};

# Empties log file. Called after rotation.

sub clearlog{
    open (my $fh, '>', $cfg->{'files'}->{'log'})
        or die "Can't open $cfg->{'files'}->{'log'}";
    close $fh;
};

# Redirects output and redirects input from /dev/null

sub daemonize{
    say "Dropping into background.";
    say "Please see $cfg->{'files'}->{'log'} later.";
    open(STDIN, '<', '/dev/null');
    open(STDOUT, '>>', $cfg->{'files'}->{'log'});
    open(STDERR, ">&STDOUT");

}

# Sets STDOUT to the working log file. Called after log rotation.

sub resetoutput{
    open(STDOUT, '>>', $cfg->{'files'}->{'log'});

}

# Takes list of links from @ARGV and appends them to the working list file.

sub addlist{
    die "No links given." unless ($ARGV[0]);
    open (my $fh, '>>', $cfg->{'files'}->{'list'})
        or die "Can't open $cfg->{'files'}->{'list'}";
    foreach my $url (@ARGV){
        say "$url is not a valid link" & next unless (is_uri($url));
        say "Adding $url to queue...";
        say $fh $url;
    }
    close $fh;
};

# Downloads youtube videos from working list file.

sub getvids{
#    chdir $cfg->{'dirs'}->{'tmp'};
    my @cmds;
    my $output = $cfg->{'dirs'}->{'done'} . $cfg->{'option'}->{'ytdlouttemp'};
    my $vids = getlist();
    if ($test == 0){
        clearlist();
    }
    push @cmds, 'nohup' if ($daemon == 1 );
    push @cmds, '/usr/local/bin/youtube-dl';
    if ($test == 1){
        push @cmds, '--simulate';
    }

    # Build the shell command based on arguments and variables.

    push @cmds, (
        '-r',"$cfg->{'option'}->{'rate'}",
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

# Makes the script wait for the naptime value.

sub takeanap{
    say "Nothing to do. Sleeping for $cfg->{'option'}->{'naptime'} seconds." unless($daemon == 1);
    my $timer = $cfg->{'option'}->{'naptime'};
        print "+++ seconds left\r" unless($daemon == 1);
    until ( $timer == 0 or $quit == 1 ){
        print "$timer\n" unless($daemon == 1);
        --$timer;
        sleep 1;
}
say '';
};

# END

sub END{
#sub quitting{
    die "User sent interrupt." if ($interrupted == 1);
    exit 0;

};

# Rotates the log. Called when checklogsize decides the log is too big.

sub rotatelog{
    say "Beginning Log Rotation";

    # Getting formats of current time.

    my @times = getdate();

    #Building the compressed logfile name.

    my $logfile = $cfg->{'dirs'}->{'logs'} . $times[0] . '-' . $times[1] . '-' . ".ytdl.log.gz";
    say "Log is being rotated into $logfile";

    # Redirecting STDOUT to temporary log file

    open(STDOUT, '>>', $cfg->{'files'}->{'tmplog'});

    # Opening log file for compression.

    open (my $fh, '<', $cfg->{'files'}->{'log'}) or die "Can't open $cfg->{'files'}->{'log'}: $?";

    # Creating gzip object to write to.

    my $zip = new IO::Compress::Gzip $logfile or say "gzip failed: $GzipError";

    local $/ = undef;

    # Slurping log file into $data

    my $data = <$fh>;
    # Closing log file
    close $fh;
#    print $zip $fh;
    # Compressing $data into gzipped log file.
    $zip->print($data);
    #Closing gzip file
    close $zip;
    # Emptying log file.
    clearlog();
    # Redirect STDOUT to working log file
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
    my $logsize = getfilesize($cfg->{'files'}->{'log'})
        or say "Cannot open file $cfg->{'files'}->{'log'}: $?";
    if ( $logsize > $cfg->{'option'}->{'rotatesize'}){
        say "Log file is too large! Beginning log rotation.";
        rotatelog();
    } else {
        my @times = getdate();
        say "beep boop\n $times[0]\t$times[1]\n";
#        say "Log file size: $logsize bytes."
    };
};

sub catch_hup {
    # This catches the HUP signal.
    my $signal = shift;
    say "Somebody sent me a SIG$signal.\nI'm going to ignore them and close STDIN.";
    close STDIN;
}


startup();

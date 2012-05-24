#!/usr/bin/perl
#
#

use warnings;
use strict;

use Data::Dumper;
use DateTime;
use DateTime::Format::Strptime;
use Getopt::Std;


my $DEBUG;
my %opts;

my $logfile;
my %requests;

my $template_http_sample = "http_sample_template.xml";
my $template_time_delay = "time_delay_template.xml";
my $template_header = "template_header.xml";
my $template_footer = "template_footer.xml";

my $dt_format = new DateTime::Format::Strptime(pattern => '%d/%b/%Y:%H:%M:%S');


# Pull in the templates
open(FH, "< $template_http_sample") or die("Couldn't open http template: $template_http_sample\n");
my @http_sample = <FH>;
close(FH);

open(FH, "< $template_time_delay") or die("Couldn't open time delay template: $template_time_delay\n");
my @time_delay = <FH>;
close(FH);

open(FH, "< $template_header")  or die("Couldn't open time delay template: $template_header\n");
my @header = <FH>;
close(FH);

open(FH, "< $template_footer") or die("Couldn't open time delay template: $template_footer\n");
my @footer = <FH>;
close(FH);
# End template loads



# Parse the command line options
getopts("df:", \%opts);
$DEBUG = defined($opts{d}) ? 1 : 0;

if( defined($opts{f}) ){
    $logfile = $opts{f};
}

# Pass in a file with -f or use standard in as a fallback
if($logfile){
    open(FH, "< $logfile") or die("Couldn't open access log");
}else{
    open(FH, "<-") or die("Couldn't open stdin\n");
}

# Parse the access log
while(<FH>){
    # 192.168.100.115 - - [13/May/2012:03:37:13 -0500] "GET /skin/frontend/enterprise/ecomom/images/home_popup/sign_up.png HTTP/1.0" 304 - "-" "Amazon CloudFront"
    # Capture the IP, timestamp without the timezone+, URL and response code
    if(m/^([.[:digit:]]+)           # Capture IP address
        (?:\s|\-)*                  # Skip the Dashes
        \[([\/:[:alnum:]]+)\s*      # Capture the Date and Time without the tz
        [-[:digit:]]+\]\s           # TZ skip
        "([[:print:]]+)"\s          # Caputre the request
        ([[:digit:]]+)\s            # Capture the response code
        [[:print:]]*                # Skip everything up to the agent string
        \"([[:print:]]+)\"$         # Caputre the agent string
        /x){
        my $ip = $1;
        my $date = $2;
        my $request = $3;
        my $rescode = $4;
        my $agent = $5;

        my $reqtype;
        my $requrl;

        # We want 200s and 300s, skip the rest
        if($rescode !~ m/(?:200|301|304)/){
            print("DEBUG: Skipping bad rescode: $_\n") if($DEBUG);
            next;
        }

        # Parse the request in to GET/POST type and grab the url
        if($request =~ m/^(GET|POST) ([[:print:]]+) HTTP\/1.[01]/){
            $reqtype = $1;
            $requrl = $2;
        }else{
            print("DEBUG: Bad request parse: $request\n") if($DEBUG);
        }

        if($agent =~ m/-/){
            $agent = "F5";
        }

        if(! defined($requests{$agent})){
            $requests{$agent} = [];
        }

        push($requests{$agent}, [$reqtype, $requrl, $date]);
        #push(@{$requests{$agent}}, [$reqtype, $requrl, $date]);
    
    }else{
        print("DEBUG: NO MATCH: $_\n") if($DEBUG);
    }
}
close(FH);

print("results:\n\n");
#print Dumper %requests;
#exit(0);

foreach my $k (keys %requests){
    # Hold the timestamps of the samples, resetting every loop
    my $dt1;
    my $dt2;


    # The test filename will be the first 20 characters of the agent string
    # Strip forward slashes and parens, spaces to underscores
    my $test_file = substr($k, 0, 20);
    $test_file =~ s/(?:\(|\)|\/|\:|\+)//g;
    $test_file =~ s/\s+/_/g;

    # Write the jmeter header first
    open(TEST_FH, "> testfiles/$test_file.jmx") or die("Couldn't open file: $test_file.jmx : $!\n");
    foreach (@header){
        my $line = $_;
        $line =~ s/testname="\$TEST_NAME\$/testname="$test_file/;
        print(TEST_FH $line);
    }

    # Loop through each of the requests this browser string created
    print("DEBUG: Browser: $k\n") if($DEBUG);
    foreach my $request (values @{$requests{$k}}){
        my $reqtype = @$request[0];
        my $requrl = @$request[1];
        my $reqtime = $dt_format->parse_datetime(@$request[2])->epoch;
        print("  $reqtype : $requrl : $reqtime \n") if($DEBUG);

        # Get the page name and set it as the testname="$NAME_OF_PAGE$" in the tempaltes
        my $page_name;
        if($requrl =~ m/\/([-._,a-z0-9]+)           # Grab the last bit from the last forward slash
                        (?:\?[-._=&+,[:alnum:]]*)?  # Skip any bits after a ?
                        (?:\s*|\/)$                 # Ignore trailing white space or slashes
                        /xi
                        ){
            $page_name = $1;
            print("DEBUG: PAGE: $page_name\n") if($DEBUG);
        }
        elsif($requrl =~ m/\//){
            $page_name = "index";
        }
        else{
            print("DEBUG: Didn't match page name: $requrl\n");
        }

        # In the GET requests, we need to replace:
        # HTTPSampler.path">$PATH_TO_UPDATE$< with the url
        if($reqtype =~ m/GET/){
            #print(TEST_FH "<hashTree>\n");
            foreach (@http_sample){
                my $line = $_;
                $line =~ s/testname="\$NAME_OF_PAGE\$/testname="$page_name/;
                $line =~ s/HTTPSampler.path">\$PATH_TO_UPDATE\$/HTTPSampler.path">$requrl/;
                print(TEST_FH $line);
            }
            print(TEST_FH "<hashTree/>\n");
        }
        elsif($reqtype =~ m/POST/){
            print("WARNING: Work on POSTS!\n");
        }
        else{
            print("Vas ist Das?: $reqtype\n");
        }

        # Set the current time to $dt2
        # Check if dt1 has been set, it won't exist on our first pass
        # dt1 gets set at the end of this foreach section from dt2

        $dt2 = $reqtime;
        if(defined($dt1) && $dt1 ne ''){
            my $time_diff = int($dt2) - int($dt1);
            $time_diff *= 1000;
            print("DEBUG: TIMES: $dt1 : $dt2 : $time_diff\n") if($DEBUG);

            # max time delay of ~60 sec
            if($time_diff > 60000){
                $time_diff = 60000;
            }

            #print(TEST_FH "<hashTree>\n");
            foreach (@time_delay){
                my $line = $_;
                $line =~ s/testname="\$NAME_OF_PAGE\$/testname="$page_name Timer/;
                $line =~ s/ConstantTimer.delay">\$TIME_IN_MS\$/ConstantTimer.delay">$time_diff/;
                #chomp($line);
                #print("DEBUG: WRITING: $line \n") if($DEBUG);
                print(TEST_FH $line);
            }
            print(TEST_FH "<hashTree/>\n");
        }
        else{
            print("DEBUG: dt1 didnt exist\n") if($DEBUG);
        }

        $dt1 = $dt2;
        print("DEBUG: end req\n\n") if($DEBUG);
    }

    # Write the footer
    foreach (@footer){
        print(TEST_FH $_);
    }

    close(TEST_FH);
}

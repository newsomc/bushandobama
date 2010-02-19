BEGIN { 
    my $base_module_dir = (-d '/home/si601/perl' ? '/home/si601/perl' : ( getpwuid($>) )[7] . '/perl/'); 
    unshift @INC, map { $base_module_dir . $_ } @INC; 
}

use URI;
use LWP::UserAgent;
use HTTP::Cookies;
use HTML::Strip;
use HTML::Strip::Whitespace qw(html_strip_whitespace);
use WWW::Mechanize;
use Data::Dumper;


#create output directories
mkdir("obama_press", 0777) || print $!;
mkdir("obama_debug", 0777) || print $!;
 
dbmopen(%wordCollector,'obama_countDB',0666);
 
open(OUTD, ">obama_debug/debug_report.txt")||die("could not open output debug file\n");
 
open(OUTF, ">obamna_term_freq_report.txt")||die("could not open output file\n");
print OUTF "term\tcount\n";

# intialize the HTML stripper
my $hs = HTML::Strip->new();
my $mech = WWW::Mechanize->new();
# initialize the User Agent that is going to fetch the page
my $ua = LWP::UserAgent->new;
$ua->agent("my bot 1.0");
$ua->cookie_jar($self->{'cookies'});

# give it a timeout so it doesn't hang for too long
$ua->timeout(1000); 

print "gather URLs\n";


for($i = 0; $i <= 7; $i++){
   $mech->get ("http://www.whitehouse.gov/briefing-room/presidential-actions/presidential-memoranda?page=".$i);
   @pressLinkObjects = $mech->find_all_links(url_regex=> qr/the-press-office|the_press_office/); 
    #print "test: @pressLinkObjects";
   foreach $linkObject (@pressLinkObjects)
    {
	$foundUrl = $linkObject->url();
	#print $foundUrl."\n";
	push(@pressLinks, $foundUrl);
    }
}

print "Gathering text.\n";

#====================================
# Grab URLs.
#====================================
$count = 0;       
foreach $link (@pressLinks)
{	
    open (OUT, ">obama_press/obama_whitehouse_".$count++.".txt") || die "Couldn't open file!"; 
    $urltoget = "http://www.whitehouse.gov".$link;
    my $url=URI->new($urltoget);
    my $req=HTTP::Request->new;
    $req->method('GET');
    $req->uri($url);
    my $res = $ua->request($req);
    # print out redirects and errors if they occur
    if ($res->is_redirect) 
    {
	print STDERR __LINE__, " Redirect to ", $res->header('Location'), "\n";
    } 
    elsif ($res->is_error)
    {
	print STDERR __LINE__, " Error: ", $res->status_line, " ", $res;
    } 
    else 
    {
	$stories = $res->content;
	my $clean_text = $hs->parse($stories);
	html_strip_whitespace(
	    "source" =>\$clean_text,
	    "out" =>\$less_whitespace);
	print OUT "$less_whitespace";
	print "Created obama_whitehouse_".$count.".txt\n"; 
      }
  }


#====================================================
# pull usefull parts from text (add to term database)
#====================================================
 
opendir (FOLDER, "./obama_press") || die "sorry, could not open obama_press files";
 
my @filelist = readdir (FOLDER);
 
foreach my $filename (@filelist){
 
	open (IN,"./obama_press/$filename") || die "Could not open $filename\n";
  
	print "Gathering terms from $filename\n";
  
	while (my $line = <IN>){
		my @splitline = split(/\b/, lc $line);
 
		foreach my $word (@splitline){
 
				my @splitword = split(//,$word);
 
				if (defined $splitword[0]){
 
					if ($splitword[0] =~ /\w/){
 
						$wordCollector{$word}++;
						print OUTD "$word $wordCollector{$word}\n";
					}
					else {
						next;
					}
				}
			}
		}	
}
 
foreach $key (sort {$wordCollector{$b} <=> $wordCollector{$a}} keys %wordCollector){
	print OUTF "$wordCollector{$key} $key\n";
}
 
print "Done\n";


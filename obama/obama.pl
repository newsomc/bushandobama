
use URI;
use LWP::UserAgent;
use HTTP::Cookies;
use HTML::Strip;
use HTML::Strip::Whitespace qw(html_strip_whitespace);
use WWW::Mechanize;
use Lingua::Stem;
use Data::Dumper;


#create output directories, documents and database
mkdir("obama_press", 0777) || print $!;
mkdir("obama_debug", 0777) || print $!; 
dbmopen(%wordCollector,'obama_countDB',0666); 
open(OUTD, ">obama_debug/debug_report.txt")||die("could not open output debug file\n"); 
open(OUTF, ">obamna_term_freq_report.txt")||die("could not open output file\n");
print OUTF "term\tcount\n";

# intialize HTML stripper object
my $hs = HTML::Strip->new();

#initalize Mechanize object
my $mech = WWW::Mechanize->new();

# initialize the User Agent 
my $ua = LWP::UserAgent->new;
$ua->agent("my bot 1.0");
$ua->cookie_jar($self->{'cookies'});
$ua->timeout(1000); 

#initialize stemmer object
my $stemmer = Lingua::Stem->new(-locale => 'EN-UK');
$stemmer->stem_caching({ -level => 2 });

#open the stopwords file and load the stop list into an array
@stop_words = ();

open(STOP, ">stop_words_stem.txt")||die("could not open stop words file\n");

foreach $line (<STOP>) {
    chomp($line);
	push(@stop_words, $line);
}

#initialize counting variables
$wordcount = 0;
$doccount = 0;


print "gathering data.\n";


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

print "URL collection done.\n";
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
	
	$doccount++;
	
	#open the file
	open (IN, "./obama_press/$filename") || die "sorry, could not open $filename\n";
  
	#status display in terminal
	print "Gathering terms from $filename\n";
  
	#token indicating the presence of real content set to zero on document load
	$foundContent = 0;
  
	#loop file line by line
	while (my $line = <IN>){
		
		#if the real content has not been found
		if ($foundContent == 0){
		
			#remove leading and trailing whitespace from line
			$line =~ s/^\s*//;
			$line =~ s/\s*$//;
		
			#split the line into words
			my @splitline = split(/\W/, $line);
		
			#check the first word of the line
			if ($splitline[0] eq "SUBJECT"){
			
				#if first word is SUBJECT
					#update token
					$foundContent = 1;
					#grab the words from that line for the term freq hash
					foreach my $word (@splitline){
						
						# stemmer requires a list isntead of a scalar
						@single_word_list = $word;
						
						#perform stemming
						$stemmed_word = $stemmer -> stem(@single_word_list);
						
						#get stemmed word back from anonymous array
						$candidate = $stemmed_word->[0];
						
						#check for stop words
							#if incoming word is found in the stop words array it is counted but not added to the term list
							if(grep $_ eq $candidate, @stop_words){
								$wordcount++;
							}else{
							#if incoming word is not found in the stop words array it is counted and added to the term list
								$wordCollector{$candidate}++;
								$wordcount++;
							}#close of else
						
					}#closes foreach word loop
					#go to the next line
					next;
			}else{
				
				#if the first word is not SUBJECT
				#go to next line
				next;
			} #close else eq subject if statement
			
			
			
		} #end if foundContent == 0
		
		#if the real content has been found
		if ($foundContent == 1){
			
			#remove leading and trailing whitespace from line
			$line =~ s/^\s*//;
			$line =~ s/\s*$//;
		
			#split the line into words
			my @splitline = split(/\W/, $line);
		
			#add the lines words to the term freq hash
			foreach my $word (@splitline){			
						@single_word_list = $word;
							
						$stemmed_word = $stemmer -> stem(@single_word_list);
						
						print OUTD "$stemmed_word->[0]\n";
						
						$candidate = $stemmed_word->[0];
						
							if(grep $_ eq $candidate, @stop_words){
								$wordcount++;
							}else{
								$wordCollector{$candidate}++;
								$wordcount++;
							}
						
			}#close foreach word loop
		
		}#close if found content if statement
		
	} #end while next line
} #end foreach filename

#create output document for term frequencies
foreach $key (sort {$wordCollector{$b} <=> $wordCollector{$a}} keys %wordCollector){
	print OUTF "$wordCollector{$key} $key\n";
}

#final status statement
print " $doccount press documents contain $wordcount words\n";

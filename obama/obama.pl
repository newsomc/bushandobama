#----------------------------------------------------------------------------
#
#		Preparation
#
#----------------------------------------------------------------------------
use URI;
use LWP::UserAgent;
use HTTP::Cookies;
use HTML::Strip;
use HTML::Strip::Whitespace qw(html_strip_whitespace);
use WWW::Mechanize;
use Data::Dumper;
use Lingua::Stem;
use Lingua::StopWords qw( getStopWords );
use Lingua::EN::Bigram;
use File::Slurp;


#
# initialize output directories, documents and databases
#
mkdir("working_data", 0777) || print $!;
mkdir("working_data/memoranda_files", 0777) || print $!;
mkdir("working_data/debug", 0777) || print $!;

mkdir("output", 0777) || print $!;

dbmopen(%wordCollector,'working_data/bho_countDB',0666);

open(OUTD, ">working_data/debug/debug.txt")||die("could not open output debug file\n");

open(OUTS, ">working_data/full_doc_collection_obama.txt")||die("could not open single collection file\n");

open(OUTF, ">output/term_freq_report_obama.txt")||die("could not open term frequency report file\n");

open(OUTB, ">output/bigram_freq_report_obama.txt")||die("could not open bigram frequency file\n");

open(OUTTS, ">output/bigram_tscore_report_obama.txt")||die("could not open bigram t-score report file\n");

#
# initialize the User Agent object
#
my $ua = LWP::UserAgent->new;
$ua->agent("my bot 1.0");
$ua->cookie_jar($self->{'cookies'});
$ua->timeout(1000); 

#
# initialize www mechanize object
#
my $mech = WWW::Mechanize->new();

#
# intialize the HTML stripper object
#
my $hs = HTML::Strip->new();

#
# initialize the Stemmer object
#
my $stemmer = Lingua::Stem->new(-locale => 'EN-UK');
$stemmer->stem_caching({ -level => 2 });

#
#initialize and get stop word array
#
my $stopwords = getStopWords('en');

#
#initialize bigram maker
#
$bigram = Lingua::EN::Bigram->new;

#
#initialize counting variables
#
$wordcount = 0;
$doccount = 0;
$linecount = 0;


#----------------------------------------------------------------------------
#
#		Start of processing
#
#----------------------------------------------------------------------------
######################################
#
# Gather urls that link to memoranda
#
#####################################

print "starting to gather data.\n";

for($i = 0; $i <= 7; $i++){
   
   $mech->get ("http://www.whitehouse.gov/briefing-room/presidential-actions/presidential-memoranda?page=".$i);
   
   @pressLinkObjects = $mech->find_all_links(url_regex=> qr/the-press-office|the_press_office/); 
   
   #print "test: @pressLinkObjects";
   
   foreach $linkObject (@pressLinkObjects){
	
	$foundUrl = $linkObject->url();
	#print $foundUrl."\n";
	push(@pressLinks, $foundUrl);
   }
}

print "Done with URL collection.\n";

######################################
#
# Gather raw memoranda texts into text files
#
######################################

print "Now gathering raw text of memoranda.\n";

$count = 0;

foreach $link (@pressLinks)
{	
    open (OUT, ">working_data/memoranda_files/obama_whitehouse_".$count++.".txt") || die "Couldn't open file!"; 
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
	#html_strip_whitespace(
	 #   "source" =>\$clean_text,
	  #  "out" =>\$less_whitespace);
	#print $less_whitespace."\n";
	print OUT $clean_text;
	print "Created obama_whitehouse_".$count.".txt\n"; 
      }
  }

	
#######################################
#
# pull usefull parts from text and single text
#
#######################################

opendir (FOLDER, "working_data/memoranda_files") || die "sorry, could not open /memoranda_files";
		
my @filelist = readdir (FOLDER);

foreach my $filename (@filelist){
	
	$doccount++;
	
	#open the file
	open (IN, "working_data/memoranda_files/$filename") || die "sorry, could not open $filename\n";
  
	#status display in terminal
	print "locating relevant secion of $filename\n";
  
	#token indicating the presence of real content set to zero on document load
	$found_content_start = 0;
	$found_content_end = 0;
  
	#loop file line by line
	while (my $line = <IN>){
		
		#if the real content has not been found
		if (($found_content_start == 0) and ($found_content_end == 0)){
		
			#remove leading and trailing whitespace from line
			$line =~ s/^\s*//;
			$line =~ s/\s*$//;
		
			#split the line into words
			my @splitline = split(/\W/, $line);
			$linecount++;
		
			#check the first word of the line
			#if first word is SUBJECT
			if ($splitline[0] eq "SUBJECT"){
			
				#print a line, with stopwords removed to the single text output file
				@stopped_line = grep { !$stopwords->{$_} } @splitline;
				
				#perform stemming
				$stemmmed_words_array = $stemmer->stem(@stopped_line);
				
				@clean_array = @$stemmmed_words_array;

				foreach $part (@clean_array){
				
					print OUTS "$part ";
					$wordcount++;
					
				}
				
				print OUTS "\n";

				#update token to indicate start of memorandum
				$found_content_start = 1;
				
				#go to the next line
				next;
			}else{
	
				#if the first word is not SUBJECT
				#go to next line
				next;
				
			} #close else eq subject if statement
			
		} #end if foundContent == 0
		
		#if the real content has been found
		if (($found_content_start == 1) and ($found_content_end == 0)){

			print OUTS "\n";
			
			#remove leading and trailing whitespace from line
			$line =~ s/^\s*//;
			$line =~ s/\s*$//;
		
			#split the line into words
			my @splitline = split(/\W/, $line);
			$linecount++;
			
			if ($splitline[0] eq "BARACK"){
			
					$found_content_end = 1;
					next;
			}
		
			#print a line, with stopwords removed to the single text output file
			@stopped_line = grep { !$stopwords->{$_} } @splitline;
				
			#perform stemming
			$stemmmed_words_array = $stemmer->stem(@stopped_line);
				
			@clean_array = @$stemmmed_words_array;

			foreach $part (@clean_array){
				
				print OUTS "$part ";
				$wordcount++;
					
			}
			
			#go to the next line
			next;
		
		}#close if found content if statement
		
	} #end while next line
} #end foreach filename

#######################################
#
# gather data
#
#######################################

my $full_doc_file = read_file( 'working_data/full_doc_collection_obama.txt' ) ;

$bigram->text($full_doc_file);

# get bigram count
print "Getting bigram count.\n";
$bigram_count = $bigram->bigram_count;

# list the bigrams according to frequency
foreach ( sort { $$bigram_count{ $b } <=> $$bigram_count{ $a } } keys %$bigram_count ) {

	print OUTB $$bigram_count{ $_ }, "\t$_\n";

}


# get word count
print "Getting word count.\n";

$word_count = $bigram->word_count;

# list the words according to frequency print to text file
foreach ( sort { $$word_count{ $b } <=> $$word_count{ $a } } keys %$word_count ) {

	print OUTF $$word_count{ $_ }, "\t$_\n";

}

# get t-score
print "Getting bigram t scores.\n";
 
$tscore = $bigram->tscore;

# list bigrams according to t-score
foreach ( sort { $$tscore{ $b } <=> $$tscore{ $a } } keys %$tscore ) {

	print OUTTS "$$tscore{ $_ }\t" . "$_\n";

}

#final status statement
print "$wordcount words in $linecount lines from $doccount documents.\n";



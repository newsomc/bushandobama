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

dbmopen(%wordCollector,'working_data/gwb_countDB',0666);

open(OUTD, ">working_data/debug/debug.txt")||die("could not open output debug file\n");

open(OUTS, ">working_data/full_doc_collection_bush.txt")||die("could not open single collection file\n");

open(OUTF, ">output/term_freq_report_bush.txt")||die("could not open term frequency report file\n");

open(OUTB, ">output/bigram_freq_report_bush.txt")||die("could not open bigram frequency file\n");

open(OUTTS, ">output/bigram_tscore_report_bush.txt")||die("could not open bigram t-score report file\n");

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


#----------------------------------------------------------------------------
#
#		Start of processing
#
#----------------------------------------------------------------------------

print "starting to gather data.\n";

######################################
#
# Gather urls that link to memoranda
#
#####################################


#set years to gather documents
$start_year = 2008;
$stop_year = 2009;


#initialize an array for urls
@memorandaLinks = ();

#for each year (defined by start_year and stop_year) and month find the links with the text 'memorandum'
#save each link to the array 
for($year = $start_year; $year < $stop_year; $year++){  

	for($month = 1; $month <= 12; $month++){
	
		if ($month < 10){
		
			$mech->get ("http://georgewbush-whitehouse.archives.gov/news/releases/$year/0$month/");
			
			@foundLinkObjects = $mech->find_all_links(text_regex => qr/(memorandum)/i);
			
			foreach $linkObject (@foundLinkObjects){
			
				$foundUrl = $linkObject->url();
				
				push(@memorandaLinks, $foundUrl);
			}
			
		}else{
		  
			$mech->get ("http://georgewbush-whitehouse.archives.gov/news/releases/$year/$month/");
			
			@foundLinkObjects = $mech->find_all_links(text_regex => qr/(memorandum)/i);
			
			foreach $linkObject (@foundLinkObjects){
			
				$foundUrl = $linkObject->url();
				
				push(@memorandaLinks, $foundUrl);
			}
	} #close else statement
	
} #close month loop	
} #close year loop

print "Done with URL collection.\n";


######################################
#
# Gather raw memoranda texts into text files
#
######################################

print "Now gathering raw text of memoranda.\n";

$memorandaPage = 0;

#loop through url array and create a text file containing the parsed and stripped html document
foreach $link (@memorandaLinks){ 
	
	open(OUT, ">working_data/memoranda_files/mempage_$memorandaPage.txt")||die("could not open output file for mem # $memorandaPage\n");
	
	$urltoget = "http://georgewbush-whitehouse.archives.gov".$link;
	
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
		}else{
	    
	$content = $res->content;
	
	my $clean_text = $hs->parse($content);
	
	print OUT $clean_text;
	
	print "created file mempage_$memorandaPage.txt\n";

	$memorandaPage++;
	
	} #closes else statement
    } #closes foreach loop

	
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
		
			#check the first word of the line
			#if first word is SUBJECT
			if ($splitline[0] eq "SUBJECT"){
			
				#print a line, with stopwords removed to the single text output file
				$clean_line = join ' ', grep { !$stopwords->{$_} } @splitline;
				
				#re-do stemming
				#my $stemmmed_words_anon_array = $stemmer->stem(@words);
				
				print OUTS $clean_line;
				
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
			
			if ($splitline[0] eq "GEORGE"){
			
					$found_content_end = 1;
					next;
			}
		
				$clean_line = join ' ', grep { !$stopwords->{$_} } @splitline;
				
				print OUTS $clean_line;
				
				print OUTS "\n";
			
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

my $full_doc_file = read_file( 'working_data/full_doc_collection_bush.txt' ) ;

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
print "Done\n";

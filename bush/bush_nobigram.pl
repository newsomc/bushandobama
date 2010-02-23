######################################
#
# Preparation
#
#####################################

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

#
# initialize output directories, documents and databases
#
mkdir("working_data", 0777) || print $!;
mkdir("working_data/memoranda_files", 0777) || print $!;
mkdir("working_data/debug", 0777) || print $!;

mkdir("output", 0777) || print $!;

dbmopen(%wordCollector,'working_data/gwb_countDB',0666);

open(OUTD, ">working_data/debug/debug.txt")||die("could not open output debug file\n");

open(OUTS, ">output/full_doc_collection_bush.txt")||die("could not open single collection file\n");

open(OUTF, ">output/term_freq_report_bush.txt")||die("could not open output file\n");
print OUTF "term\tcount\n";

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
#open the stopwords file and load the stop list into an array
#

@stop_words = ();

open(STOP, "<stop_words_stem.txt")||die("could not open stop words file\n");

foreach $line (<STOP>) {
    chomp($line);
	push(@stop_words, $line);
}

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
# pull usefull parts from text and create term list
#
#######################################

opendir (FOLDER, "working_data/memoranda_files") || die "sorry, could not open /memoranda_files";
		
my @filelist = readdir (FOLDER);

foreach my $filename (@filelist){
	
	$doccount++;
	
	#open the file
	open (IN, "working_data/memoranda_files/$filename") || die "sorry, could not open $filename\n";
  
	#status display in terminal
	print "Gathering terms from $filename\n";
  
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
			if ($splitline[0] eq "SUBJECT"){
			
					print OUTS "\n";
					
				#if first word is SUBJECT
					#update token
					$found_content_start = 1;
					#grab the words from that line for the term freq hash
					foreach my $word (@splitline){
						
						print OUTS "$word ";
						
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
		
			#add the lines words to the term freq hash
			foreach my $word (@splitline){			
						print OUTS "$word ";
						
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
print "From $start_year to $stop_year $doccount memoranda contain $wordcount words\n";

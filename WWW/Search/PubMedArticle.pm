# PubMedArticle.pm
# by Jim Smyser
# Copyright (C) 2000 by Jim Smyser 
# $Id: PubMedArticle.pm,v 1.1 2006/09/08 01:55:32 zhangc Exp $


package WWW::Search::PubMedArticle;

=head1 NAME

WWW::Search::PubMedArticle - class for searching National Library of Medicine 

=head1 SYNOPSIS

use WWW::Search;

$query = "lung cancer treatment"; 
$search = new WWW::Search('PubMedArticle');
$search->native_query(WWW::Search::escape_query($query));
$search->maximum_to_retrieve(100);
while (my $result = $search->next_result()) {

$url = $result->url;
$title = $result->title;
$desc = $result->description;

print <a href=$url>$title<br>$desc<p>\n"; 
} 

=head1 DESCRIPTION

WWW::Search class for searching National Library of Medicine
(PubMed). If you never heard of PubMed, Medline or don't know
the difference between a Abstract and Citation -- you then
can live without this backend.

This class exports no public interface; all interaction should
be done through WWW::Search objects.

=head1 AUTHOR

C<WWW::Search::PubMedArticle> is written and maintained by Jim Smyser
<jsmyser@bigfoot.com>.

=head1 COPYRIGHT

WWW::Search Copyright (c) 1996-1998 University of Southern California.
All rights reserved. PubMedArticle.pm by Jim Smyser.                                           
                                                               
THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.

=cut
#'

#####################################################################
require Exporter;
@EXPORT = qw();
@EXPORT_OK = qw();
@ISA = qw(WWW::Search Exporter);
$VERSION = '1.0';

use Carp ();
use WWW::Search(qw(generic_option strip_tags));

require WWW::SearchResult;

sub native_setup_search 
{
    my($self, $native_query, $native_options_ref) = @_;
    $self->{_debug} = $native_options_ref->{'search_debug'};
    $self->{_debug} = 2 if ($native_options_ref->{'search_parse_debug'});
    $self->{_debug} = 0 if (!defined($self->{_debug}));
    $self->{agent_e_mail} = 'jsmyser@bigfoot.com';
    $max =  $self->maximum_to_retrieve;
    $self->user_agent('user');
    $self->{_next_to_retrieve} = 1;
    $self->{'_num_hits'} = 0;
    if (!defined($self->{_options})) 
	{
		$self->{_options} = 
		{
 			'search_url' => 'http://www.ncbi.nlm.nih.gov:80/entrez/query.fcgi?cmd=Retrieve&db=PubMed&dopt=XML',
			'list_uids' => $native_query
		};
		#modified by Chaolin Zhang here. allow the user to override options
    }
    my $options_ref = $self->{_options};    
	if (defined($native_options_ref))
    {
        # Copy in new options.
        foreach (keys %$native_options_ref)
        {
        	$options_ref->{$_} = $native_options_ref->{$_};
        } 
	} 
        # Process the options.
    my($options) = '';
    foreach (sort keys %$options_ref)
    {
        next if (generic_option($_));
        $options .= $_ . '=' . $options_ref->{$_} . '&';
    }
    chop $options;#the string $options is not added to search_url?
    $self->{_next_url} = $self->{_options}{'search_url'} . "&". $options;

	print STDERR "options= $options\n" if $self->{_debug};
	print STDERR "_next_url = ", $self->{_next_url}, "\n" if $self->{_debug};
} 

# private
sub native_retrieve_some 
{
	

    my ($self) = @_;
    
    print STDERR "Entering sub routine WWW::Search::PubMedArticle::native_retrieve_some...\n"
	if $self->{_debug};
    # Fast exit if already done:
    return undef if (!defined($self->{_next_url}));
   	
	print STDERR "_next_url=", $self->{_next_url}, "\n" if $self->{_debug};
    
	# If this is not the first page of results, sleep so as to not
    # overload the server:
    
	print STDERR "_next_to_retrieve = ", $self->{'_next_to_retrieve'}, "\n"
	if $self->{_debug};
    $self->user_agent_delay if 1 < $self->{'_next_to_retrieve'};
            
    # Get some if were not already scoring somewhere else:
    my($response) = $self->http_request('GET', $self->{_next_url});
        
    $self->{response} = $response;
    if (!$response->is_success)
    {
		print STDERR "Http response is not successful, return undef\n" 
		if $self->{_debug};
        return undef;
    }
    $self->{'_next_url'} = undef;
	
	print STDERR "Http response is successful, go on\n" 
    if $self->{_debug};

	# parse the output
    my ($HEAD, $HITS, $DESC) = qw(HD HI DE);
    my $hits_found = 0;
    my $state = $HEAD;
    my $hit;
    my $text = '';

    #print STDERR join ("\n", $self->split_lines($response->content()))
	#if $self->{_debug};    

    # parse the output
	foreach ($self->split_lines($response->content()))
    {
        next if m@^\s+$@; # short circuit for blank lines
        
		if ($state eq $HEAD && m|\[PMID: ([\d,]+)\]</td>$|i) 
        {
        	$hit = ();
        	$hit = new WWW::SearchResult;
        	$hits_found++;
        	$hit->title($1);
        	$text = "";
        	#print "title = $1\n";
        	$state = $HITS;
		}
   		elsif ($state eq $HITS && m|^<dd><pre>(.*?)$|i) 
        {
        	$text = $1;
			$state = $DESC;
        } 
    	elsif ($state eq $DESC && m|(.*?)</font></pre></dd>|i) #text end
        {
        	
		#  	$text .= "\n".$1;
        	last;
        }
		elsif ($state eq $DESC)
		{
			$text .= "\n".$_;
			$text =~ s/&lt;/</g;
			$text =~ s/&gt;/>/g;
			$text =~ s/&quot;/\"/g;
			$hit->description($text);
			push(@{$self->{cache}}, $hit);
			#print "text=$text\n";
		}
	}

    $self->{_next_url} = undef;
	return $hits_found;
}
1;
#!/usr/bin/perl
use strict;
use utf8;
use open ':std', ':encoding(UTF-8)';
use HTML::TreeBuilder;
use CGI;
use Data::Dumper qw(Dumper);
use LWP::UserAgent;
use POSIX;
use URI::URL;
my $cg = CGI->new;

=pod
Synopsis:
http://localhost/cgi-bin/wakaba_rss.pl?url=http://2ch/board/
http://localhost/cgi-bin/wakaba_rss.pl?url=http://2ch/board/res/postnum.html
=cut

print "Content-type: text/xml\n\n";
my $base_url = $cg->param('url')||$ARGV[0];
&rssOut( &grabPosts($base_url) );

sub grabPosts {
	my ($url) = @_;
	my $lwp = LWP::UserAgent->new(agent => 'Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.36 (KHTML, like Gecko) Ubuntu Chromium/28.0.1500.52 Chrome/28.0.1500.52 Safari/537.36');
	my $res = $lwp->get($url);
	my $tree = HTML::TreeBuilder->new_from_content($res->decoded_content);
	my @posts = $tree->look_down(sub { $_[0]->attr('id') && $_[0]->attr('id') =~ /post_.*\d+/; });
	my @ret;
	for(@posts) {
		my $thread = $_->look_up(sub { $_[0]->attr('id') && $_[0]->attr('id') =~ /thread_.*\d+/; });
		my $thread_id = &getNumberFromID($thread);
		my $post_id = &getNumberFromID($_);
		die("Missing thread_id") if !$thread_id;
		my $thread_title = $thread->look_down(sub { $_[0]->attr('class') && $_[0]->attr('class') =~ /(filetitle|postsubject)/; })
			if $thread;
		my $thread_reply_btn = $thread->look_down(sub { $_[0]->attr('href') && $_[0]->attr('href') =~ /$thread_id\.html/; });
		my $thread_reply_url = $thread_reply_btn->attr('href') if $thread_reply_btn;
		$thread_reply_url =~ s/#.*//;
		my $text = $_->as_text;
		$text =~ s/&/&amp;/g;
		$text =~ s/</&lt;/g;
		$text =~ s/>/&gt;/g;
		my $thumb = $_->look_down('_tag' => 'img');
		my $thumb_url = $thumb ? $thumb->attr('src') : '';
		my $a_href = $thumb->look_up('_tag' => 'a') if $thumb;
		my $img_url = $a_href->attr('href') if $a_href;
		push @ret, {
			thread_id => $thread_id,
			thread => $thread_title && $thread_title->as_text ? $thread_title->as_text : "#$thread_id",
			id => $post_id,
			text => $text,
			link => &formatURL("$thread_reply_url#$post_id"),
			thumb_url => &formatURL($thumb_url),
			img_url => &formatURL($img_url),
		};
	};
	return(@ret);
}

sub formatURL {
	return URI::URL->new($_[0], $base_url)->abs() if $_[0];
}

sub getNumberFromID {
	my ($element) = @_;
	return if !$element;
	return $1 if $element->attr('id') && $element->attr('id') =~ /(\d+)/;
}

sub prettyPrint {
	for(@_) {
		print "--- res/$_->{thread} #$_->{id} ---\n";
		print "$_->{text}\n\n";
	}
}

sub rssOut {
	my $localtime = strftime("%a, %d %b %H:%M:%S %z", localtime);
	print <<BLOCK
<rss version="2.0">
	<channel>
		<title>$base_url</title>
		<link>http://111</link>
		<language>en</language>
		<lastBuildDate>$localtime</lastBuildDate>
BLOCK
;
	for(@_) {
		my $cdata = $_->{thumb_url} ? "<![CDATA[\n <a href='$_->{img_url}'><img src='$_->{thumb_url}' alt='$_->{id}'/></a><br/> \n]]>\n" : '';
		print <<BLOCK
			<item>
				<title>$_->{thread}</title>
				<link>$_->{link}</link>
				<description>$cdata$_->{text}</description>
			</item>
BLOCK
;
	}
print <<BLOCK
	</channel>
</rss>
BLOCK
;
}

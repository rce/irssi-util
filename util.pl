use strict;

use vars qw(%IRSSI);

%IRSSI = (
	authors     => 'Henry Heikkinen',
	contact     => 'rce@rce.fi',
	name        => 'irssi-util',
        license     => 'MIT',
	modules     => 'LWP::UserAgent JSON',
);

use LWP::UserAgent;
use JSON;

sub youtube_get_info {
	my ($id) = @_;
	my $apikey = Irssi::settings_get_str('util_youtube_apikey');
	my $ua = LWP::UserAgent->new(timeout=>30);
	$ua->agent('rce/irssi-util');

	my $url = 'https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id='.$id.'&key='.$apikey;
	my $request = HTTP::Request->new('GET', $url);
	my $response = $ua->request($request);
	unless ($response->is_success()) {
		print CLIENTCRAP "Request failed";
		print CLIENTCRAP 'Response: '.$response->content();
		return "error fetching video information";
	}
	my $json = decode_json($response->content());
	my $item = $json->{items}[0];
	my $title = $item->{snippet}->{title};
	return "YouTube: $title";
}

sub handle_message {
	my ($server, $msg, $nick, $chan) = @_;

	$_ = $msg;
	if (/https:\/\/www.youtube.com\/watch\?v=([a-z0-9_-]{11})/i) {
		$server->print($chan, youtube_get_info($1));
		return;
	}
}

sub on_message {
	my ($server, $msg, $nick, undef, $chan) = @_;
	handle_message($server, $msg, $nick, $chan);
}

sub on_own_message {
	my ($server, $msg, $chan) = @_;
	handle_message($server, $msg, $server->{nick}, $chan);
}

# Settings
Irssi::settings_add_str($IRSSI{name}, 'util_youtube_apikey', '');

# Signals
Irssi::signal_add('message public' => \&on_message);
Irssi::signal_add('message own_public' => \&on_own_message);


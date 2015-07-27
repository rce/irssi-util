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
use HTML::Parser;
use HTML::Entities;

sub get {
	my ($url) = @_;
	my $ua = LWP::UserAgent->new(timeout=>30);
	$ua->agent('rce/irssi-util');
	$ua->max_size(64 * 1024);
	return $ua->request(HTTP::Request->new('GET', $url));
}

sub get_title {
	my ($url) = @_;
	my $response = get($url);
	unless ($response->is_success()) {
		return "Error fetching title for '$url'";
	}

	if ($response->content() =~ /<title>(.*)<\/title>/) {
		return decode_entities($1);
	}
	return "";
}

sub youtube_get_info {
	my ($id) = @_;
	my $apikey = Irssi::settings_get_str('util_youtube_apikey');
	my $url = 'https://www.googleapis.com/youtube/v3/videos?part=snippet,contentDetails&id='.$id.'&key='.$apikey;
	my $response = get($url);
	unless ($response->is_success()) {
		print CLIENTCRAP "Request failed";
		print CLIENTCRAP 'Response: '.$response->content();
		return "error fetching video information";
	}
	my $json = decode_json($response->content());
	my $item = $json->{items}[0];
	my $title = $item->{snippet}->{title};
	my $duration = parse_duration($item->{contentDetails}->{duration});
	return "YouTube: $title [$duration]";
}

sub parse_duration {
	my ($pt) = @_;
	$pt =~ /P((\d+)Y)?((\d+)M)?((\d+)W)?((\d+)D)?T((\d+)H)?((\d+)M)?((\d+)S)?/;
	my ($years, $months, $weeks, $days, $hours, $minutes, $seconds)
		= ($2, $4, $6, $8, $10, $12, $14);
	# Ignore years and months because of their variable durations
	my $hh = 0 + $hours + ($days * 24) + ($weeks * 7 * 24);
	my $mm = 0 + $minutes;
	my $ss = 0 + $seconds;
	if ($hh != 0) {
		return $hh.':'.pad($mm).':'.pad($ss);
	}
	return pad($mm).':'.pad($ss);
}

sub pad {
	my ($val) = @_;
	if ($val < 10) {
		return "0$val";
	}
	return $val;
}

sub handle_message {
	my ($server, $msg, $nick, $chan) = @_;

	$_ = $msg;
	if (/(https?:\/\/)?(youtu.be\/|(www\.)?youtube.com\/(watch\?\S*v=|embed\/|v\/))([a-z0-9_-]{11})/i) {
		$server->print($chan, youtube_get_info($5));
		return;
	} elsif (/((https?:\/\/)?(\w+\.)?(\w+)(\.[a-z]{2,})(\/\S*)?)/i) {
		my $title = get_title($1);
		if ($title ne "") {
			$server->print($chan, $title);
		}
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

sub on_private_message {
	my ($server, $msg, $nick) = @_;
	handle_message($server, $msg, $nick, $nick);
}

sub on_own_private_message {
	my ($server, $msg, $target) = @_;
	handle_message($server, $msg, $server->{nick}, $target);
}

# Settings
Irssi::settings_add_str($IRSSI{name}, 'util_youtube_apikey', '');

# Signals
Irssi::signal_add('message public' => \&on_message);
Irssi::signal_add('message private' => \&on_private_message);
Irssi::signal_add('message own_public' => \&on_own_message);
Irssi::signal_add('message own_private' => \&on_own_private_message);


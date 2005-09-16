# Mail::vpopmail.pm
# $Id: vpopmail.pm,v 0.51 2005/12/15 20:36:34 jkister Exp $
# Copyright (c) 2004-2005 Jeremy Kister.
# Released under Perl's Artistic License.

$Mail::vpopmail::VERSION = "0.51";

=head1 NAME

Mail::vpopmail - Utility to get information about vpopmail managed email addresses

=head1 SYNOPSIS

use Mail::vpopmail;

my $vchkpw = Mail::vpopmail->new();

my $vchkpw = Mail::vpopmail->new(cache => 1,
                                 debug => 0);

	
=head1 DESCRIPTION

C<Mail::vpopmail> provides serveral functions for interacting with
vpopmail.  This module can be useful especially when hashing is turned
on, as you can not predict the location of the domain's nor the 
mailbox's directories.

=head1 CONSTRUCTOR

=over 4

=item new( [OPTIONS] );

C<OPTIONS> are passwed in a hash like fashion, using key and value
pairs.  Possible options are:

B<cache> - Cache results of queries (0=Off, 1=On).  Default=On.

B<debug>  - Print debugging info to STDERR (0=Off, 1=On).  Default=On.

=item get( email => $email, field => <fields> );

B<email> - the email address to get properties on

B<field> - the field(s) you want to be returned (may be comma separated):

	dir - return this domain's vpopmail domains directory

	crypt - return the encrypted password

	uid - return the uid

	gid - return the gid

	comment - return the comment, if available

	maildir - return this user's maildir
	
	quota - return the quota (you have to parse this yourself)

	plain - return the plain text password, if available
	

=head1 EXAMPLES

	use Mail::vpopmail;
	my $email = shift;
	unless(defined($email)){
		print "email address: ";
		chop($email=<STDIN>);
	}

	my $vchkpw = Mail::vpopmail->new();

	my $dir = $vchkpw->get(email => $email, field => 'dir');
	my ($crypt,$uid,$gid) = $vchkpw->get(email => $email, field => 'crypt,uid,gid');
	my $comment = $vchkpw->get(email => $email, field => 'comment');
	my $maildir = $vchkpw->get(email => $email, field => 'maildir');
	my $quota = $vchkpw->get(email => $email, field => 'quota');
	my $plain = $vchkpw->get(email => $email, field => 'plain');


=head1 CAVEATS

This version does not support SQL based vpopmail solutions.


=head1 AUTHOR

Jeremy Kister - http://jeremy.kister.net/

=cut

package Mail::vpopmail;

use strict;

my (%_cache,%_arg);

sub new {
	my $class = shift;
	%_arg = @_;

	$_arg{'cache'} = 1 unless(defined($_arg{'cache'}));
	$_arg{'debug'} = 1 unless(defined($_arg{'debug'}));

	return(bless({},$class));
}

sub Version { $Mail::vpopmail::VERSION }

sub _dir {
	my $class = shift;
	if(my $domain = shift){
		if(open(A, '/var/qmail/users/assign')){
			my $dir;
			while(<A>){
				if(/^\+${domain}\-:[^:]+:\d+:\d+:([^:]+):-:/){
					$dir = $1;
					last;
				}
			}
			close A;
			if(defined($dir)){
				$_cache{$domain}{dir} = $dir if($_arg{'cache'});
				return($dir); # this dir is not verified, it's just what vpopmail thinks
			}else{
				warn "could not find directory for domain: $domain\n" if($_arg{'debug'});
			}
		}else{
			warn "could not open /var/qmail/users/assign: $!\n" if($_arg{'debug'});
		}
	}else{
		warn "domain not supplied correctly\n" if($_arg{'debug'});
	}
	return();
}

sub get {
	my $class = shift;
	my %arg = @_;
	unless(exists($arg{'email'}) && exists($arg{'field'})){
		if($_arg{'debug'}){
			warn "email: $arg{'email'} not right\n";
			warn "field: $arg{'field'} not right\n";
		}
		return();
	}
	my ($user,$domain) = split(/\@/, $arg{'email'}); # no routing data supported
	if(defined($user) && defined($domain)){
		my (%hash,@return);
		$hash{'dir'} = (exists($_cache{$domain}{'dir'})) ? $_cache{$domain}{'dir'} : Mail::vpopmail->_dir($domain);

		if($arg{'field'} eq 'dir'){
			push @return, $hash{'dir'};
			$_cache{$arg{'email'}}{'dir'} = $hash{'dir'} if($_arg{'cache'});
		}else{
			if(exists($_cache{$arg{'email'}}{'crypt'})){
				foreach my $field (split(/,/, $arg{'field'})){
					push @return, $_cache{$arg{'email'}}{$field};
				}
			}else{
				if(open(V, "$hash{'dir'}/vpasswd")){
					my $found;
					while(<V>){
						chomp;
						if(/^${user}:([^:]+):(\d+):(\d+):([^:]*):([^:]+):([^:]+)(:([^:]+))?/){
							my %hash;
							($hash{'crypt'},$hash{'uid'},$hash{'gid'},$hash{'comment'}) = ($1,$2,$3,$4);
							($hash{'maildir'},$hash{'quota'},$hash{'plain'}) = ($5,$6,$8);
							$found=1;

							if($_arg{'cache'}){
								while(my($key,$value) = each %hash){
									$_cache{$arg{'email'}}{$key} = $value;
								}
							}

							foreach my $field (split(/,/, $arg{'field'})){
								push @return, $hash{$field};
							}
							last;
						}
					}
					close V;
					unless($found){
						warn "cannot find ${user} in ${domain}\n" if($_arg{'debug'});
					}
				}else{
					warn "cannot open $hash{'dir'}/vpasswd: $!\n" if($_arg{'debug'});
				}
			}

		}
		return (@return == 1) ? $return[0] : @return;
	}else{
		warn "email not supplied correctly\n" if($_arg{'debug'});
	}
	return();
}

1;

# Mail::vpopmail.pm
# $Id: vpopmail.pm,v 0.52 2006/09/29 15:23:41 jkister Exp $
# Copyright (c) 2004-2006 Jeremy Kister.
# Released under Perl's Artistic License.

$Mail::vpopmail::VERSION = "0.52";

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

=item get( domain => $domain, field => <field> );

B<domain> - the domain to get properties on
B<field> - the field want to be returned:

	mailboxes - return an array reference containing all the mailboxes

   all - return an array ref of hash refs of all data for the domain
	

=head1 EXAMPLES

	use strict;
	use Mail::vpopmail;

	my $vchkpw = Mail::vpopmail->new(cache=>1, debug=>0);


	# find all domains
	my $domains_aref = $vchkpw->alldomains(field => 'name');
	foreach my $domain (@${domains_aref}){
		print "$domain\n";
	}

	# find all domains and their directories
	my $dirlist_aref = $vchkpw->alldomains(field => 'dir');
	foreach my $href (@${dirlist_aref}){
		print "$href->{name} => $href->{dir}\n";
	}

	my $domain = shift;
	unless(defined($domain)){
		print "enter domain: ";
		chop($domain=<STDIN>);
	}


	# find all mailboxes in a given domain
   my $mailboxes_aref = $vchkpw->domaininfo(domain => $domain, field => 'mailboxes');
   foreach my $mailbox (@{$mailboxes_aref}){
      print "found mailbox: $mailbox for domain: $domain\n";
   }

	# find all properties for a given domains
   my $alldata_aref = $vchkpw->domaininfo(domain => $domain, field => 'all');
   foreach my $href (@{$alldata_aref}){
      print "found data for $domain:\n";
      while(my($key,$value) = each %{$href}){
         print " found $key => $value\n";
      }
   }

	# individual user stuff
	my $email = shift;
	unless(defined($email)){
		print "email address: ";
		chop($email=<STDIN>);
	}

	my $dir = $vchkpw->userinfo(email => $email, field => 'dir');
	print "dir: $dir\n";
	my ($crypt,$uid,$gid) = $vchkpw->userinfo(email => $email, field => 'crypt,uid,gid');
	print "crypt/uid/gid: $crypt/$uid/$gid\n";
	my $comment = $vchkpw->userinfo(email => $email, field => 'comment');
	print "comment: $comment\n";
	my $maildir = $vchkpw->userinfo(email => $email, field => 'maildir');
	print "maildir: $maildir\n";
	my $quota = $vchkpw->userinfo(email => $email, field => 'quota');
	print "quota: $quota\n";
	my $plain = $vchkpw->userinfo(email => $email, field => 'plain');
	print "plain: $plain\n";

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

	$_arg{cache} = 1 unless(defined($_arg{cache}));
	$_arg{debug} = 1 unless(defined($_arg{debug}));

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
				$_cache{$domain}{dir} = $dir if($_arg{cache});
				return($dir); # this dir is not verified, it's just what vpopmail thinks
			}else{
				warn "could not find directory for domain: $domain\n" if($_arg{debug});
			}
		}else{
			warn "could not open /var/qmail/users/assign: $!\n" if($_arg{debug});
		}
	}else{
		warn "domain not supplied correctly\n" if($_arg{debug});
	}
	return();
}

sub get {
	warn "get function depreciated: use userinfo instead.\n";
	return(Mail::vpopmail->userinfo(@_)); # hack for legacy support
}

sub userinfo {
	my $class = shift;
	my %arg = @_;
	unless(exists($arg{email}) && exists($arg{field})){
		if($_arg{debug}){
			warn "syntax error: email: $arg{email} field: $arg{field}\n";
		}
		return();
	}
	my ($user,$domain) = split(/\@/, $arg{email}); # no routing data supported
	warn "arg{email}: $arg{email} - user: $user - domain: $domain\n" if($_arg{debug});

	if(defined($user) && defined($domain)){
		my @return;
		my %hash = ( dir => (exists($_cache{$domain}{dir})) ? $_cache{$domain}{dir} : Mail::vpopmail->_dir($domain) );

		if($arg{field} eq 'dir'){
			push @return, $hash{dir};
			$_cache{$arg{email}}{dir} = $hash{dir} if($_arg{cache});
		}else{
			if(exists($_cache{$arg{email}}{crypt})){
			warn "cache found for $arg{email}\n" if($_arg{debug});
				foreach my $field (split(/,/, $arg{field})){
					push @return, $_cache{$arg{email}}{$field};
				}
			}else{
				if(open(VPASSWD, "$hash{dir}/vpasswd")){
					my $found;
					while(<VPASSWD>){
						chomp;
						if(/^${user}:([^:]+):(\d+):(\d+):([^:]*):([^:]+):([^:]+)(:([^:]+))?/){
							my %uhash = (crypt => $1, uid => $2, gid => $3, comment => $4,
							             maildir => $5, quota => $6, plain => $8);
							$found=1;

							if($_arg{cache}){
								while(my($key,$value) = each %uhash){
									$_cache{$arg{email}}{$key} = $value;
								}
							}

							foreach my $field (split(/,/, $arg{field})){
								push @return, $uhash{$field};
							}
							last;
						}
					}
					close VPASSWD;
					unless($found){
						warn "cannot find ${user} in ${domain}\n" if($_arg{debug});
					}
				}else{
					warn "cannot open $hash{dir}/vpasswd: $!\n" if($_arg{debug});
				}
			}
		}
		return (@return == 1) ? $return[0] : @return;
	}else{
		warn "email not supplied correctly\n" if($_arg{'debug'});
	}
	return();
}

sub alldomains {
	my $class = shift;
	my %arg = @_;
	unless($arg{field} eq 'name' || $arg{field} eq 'dir'){
		if($_arg{debug}){
			warn "syntax error: field: $arg{field}\n";
		}
		return();
	}

	if(open(ASSIGN, '/var/qmail/users/assign')){
		my @array;
		while(<ASSIGN>){
			if(/^\+([^:]+)\-:[^:]+:\d+:\d+:([^:]+):-:/){
				if($arg{field} eq 'dir'){
					push @array, { name => $1, dir => $2 };
				}else{
					push @array, $1;
				}
			}
		}
		close ASSIGN;

		return(\@array);
	}else{	
		warn "could not open /var/qmail/users/assign: $!\n" if($_arg{debug});
	}
}

sub domaininfo {
	my $class = shift;
	my %arg = @_;

	unless(exists($arg{domain}) && exists($arg{field})){
		if($_arg{debug}){
			warn "syntax error: domain: $arg{domain} - field: $arg{field}\n";
		}
		return();
	}

	my %hash = ( dir => (exists($_cache{$arg{domain}}{dir})) ? $_cache{$arg{domain}}{dir} : Mail::vpopmail->_dir($arg{domain}) );
	warn "hash{dir}: $hash{dir}\n" if($_arg{debug});
	if(open(VPASSWD, "$hash{dir}/vpasswd")){
		my @return;
		while(<VPASSWD>){
			chomp;
			if(/^([^:]+):([^:]+):(\d+):(\d+):([^:]*):([^:]+):([^:]+)(:([^:]+))?/){
				my %hash = (mailbox => $1, crypt => $2, uid => $3, gid => $4,
				            comment => $5, maildir => $6, quota => $7, plain => $9);

				if($arg{field} eq 'mailboxes'){
					push @return, $hash{mailbox};
				}elsif($arg{field} eq 'all'){
					push @return, \%hash;
				}else{
					warn "syntax error: domain field type may be 'mailboxes' or 'all'\n" if($_arg{debug});
					return();
				}

				if($_arg{cache}){
					while(my($key,$value) = each %hash){
						$_cache{$hash{mailbox}}{$key} = $value;
					}
				}
			}
		}
		close VPASSWD;
		return(\@return);

	}else{
		warn "cannot open $hash{dir}/vpasswd: $!\n" if($_arg{debug});
	}
	return();
}

1;

package Apache::CompressClientFixup;

use 5.004;
use strict;
use Apache::Constants qw(OK DECLINED);
use Apache::Log();
use Apache::URI();

use vars qw($VERSION);
$VERSION = "0.03";

sub handler {
	my $r = shift;
	my $qualifiedName = join(' ', __PACKAGE__, 'handler'); # name to log
	my $dbg_msg;
	my $uri_ref = Apache::URI->parse($r);
	if ($r->header_in('Accept-Encoding')) {
		$dbg_msg = ' with annonced Accept-Encoding: '.$r->header_in('Accept-Encoding');
	} else {
		$dbg_msg = ' with no Accept-Encoding HTTP header.';
	}
	$r->log->debug($qualifiedName.' has a client '.$r->header_in('User-Agent')
		.' which requests scheme '.$uri_ref->scheme().' over '.$r->protocol.' for uri = '.$r->uri.$dbg_msg);
	return DECLINED unless $r->header_in('Accept-Encoding') =~ /gzip/io; # have nothing to downgrade

	# since the compression is ordered we have a job:
	my $msg = ' downgrades the Accept-Encoding due to '; # message patern to log

	# Range for any Client:
	# =====================
	if ($r->header_in('Range')) {
		$r->headers_in->unset('Accept-Encoding');
		$r->log->info($qualifiedName.$msg.'Range HTTP header');
		return OK;
	}

	# NN-4.X:
	# =======
	if (($r->header_in('User-Agent') =~ /Mozilla\/4\./o) and (!($r->header_in('User-Agent') =~ /compatible/io))) {
		my $printable = lc $r->dir_config('NetscapePrintable') eq 'on';
		if ( $printable ){
			$r->headers_in->unset('Accept-Encoding');
			$r->log->info($qualifiedName.$msg.'printable for NN-4.X');
		} elsif (($r->content_type =~ /application\/x-javascript/io) or ($r->content_type =~ /text\/css/io)) {
			$r->headers_in->unset('Accept-Encoding');
			$r->log->info($qualifiedName.$msg.'content type for NN-4.X');
		}
		return OK;
	}

	# M$IE:
	# =====
	if (($uri_ref->scheme() =~ /https/io) and ($r->header_in('User-Agent') =~ /MSIE/io)) {
		$r->headers_in->unset('Accept-Encoding');
		$r->log->info($qualifiedName.$msg.'MSIE over SSL');
		return OK;
	}
	return OK;
}

1;

__END__

=head1 NAME

Apache::CompressClientFixup - Perl extension for Apache-1.3.X to avoid C<gzip> compression
for some buggy browsers.

=head1 SYNOPSIS

  PerlModule Apache::CompressClientFixup
  <Location /devdoc/Dynagzip>
      SetHandler perl-script
      PerlFixupHandler Apache::CompressClientFixup
      PerlSetVar NetscapePrintable On
      Order Allow,Deny
      Allow from All
  </Location>

=head1 INTRODUCTION

Standard gzip compression significantly scales bandwidth,
and helps to please clients, who receive the compressed content faster,
especially on dial-ups.

Obviously, the success of proper implementation of content compression depends on quality of both sides
of the request-response transaction.
Since on server side we have 6 open source modules/packages for web content compression (in alphabetic order):

=over 4

=item �Apache::Compress

=item �Apache::Dynagzip

=item �Apache::Gzip

=item �Apache::GzipChain

=item �mod_deflate

=item �mod_gzip

=back

the main problem of implementation of web content compression deals with fact that some buggy web clients
declare the ability to receive
and decompress gzipped data in their HTTP requests, but fail to keep promises
when the response arrives really compressed.

All known content compression modules rely on C<Accept-Encoding: gzip> HTTP request header
in accordance with C<rfc2616>. HTTP server should never respond with compressed content
to the client which fails to declare self capability to uncompress data accordingly.

Thinking this way, we would try to unset the incoming C<Accept-Encoding> HTTP header
for those buggy clients, because they would better never set it up...

We would separate this fix-up handler from the main compression module for a good reason.
Basically, we would benefit from this extraction, because in this case
we may create only one common fix-up handler for all known compression modules.
It would help to

=over 4

=item �Share specific information;

=item �Simplify the control of every compression module;

=item �Wider reuse the code of the requests' correction;

=item �Simplify further upgrades.

=back

=head1 DESCRIPTION

This handler is supposed to serve the C<fixup> stage on C<mod-perl> enabled Apache-1.3.X.

It unsets HTTP request header C<Accept-Encoding> for the following web clients:

=head2 Microsoft Internet Explorer

Internet Explorer sometimes loses the first 2048 bytes of data
that are sent back by Web Servers that use HTTP compression,
- Microsoft confirms for MSIE 5.5 in Microsoft Knowledge Base Article - Q313712
(http://support.microsoft.com/default.aspx?scid=kb;en-us;Q313712).

The similiar statement about MSIE 6.0 is confirmed in Microsoft Knowledge Base Article - Q312496.

In accordance with Q313712 and Q312496, these bugs affect transmissions through

=over 4

=item HTTP

=item HTTPS

=item FTP

=item Gopher

=back

and special patches for MSIE-5.5 and MSIE-6.0 were published on Internet.

Microsoft has confirmed that this was a problem in the Microsoft products.
Microsoft states that this problem was first corrected in Internet Explorer 6 Service Pack 1.

Since then, later versions of MSIE are not supposed to carry this bug at all.

Because the effect is not investigated in appropriate details,
this version of the handler does not restrict compression for MSIE,
except C<HTTPS>. By default, this version turnes compression off for MSIE over SSL.

=head2 Netscape 4.X

This is C<HTTP/1.0> client.
Netscape 4.X is failing to

=over 4

=item a) handle <script> referencing compressed JavaScript files (Content-Type: application/x-javascript)

=item b) handle <link> referencing compressed CSS files (Content-Type: text/css)

=item c) display the source code of compressed HTML files

=item d) print compressed HTML files

=back

See detailed description of these bugs at
http://www.schroepl.net/projekte/mod_gzip/browser.htm - Michael Schroepl's Web Site.

This version serves cases (a) and (b) as default for this type of browsers.
This version serves cases (c) and (d) conditionally:
To activate printability for C<Netscape Navigator 4.X> you need to place

    PerlSetVar NetscapePrintable On
      
in your C<httpd.conf>. It turns off any compression for that buggy browser.

=head2 Partial Request from Any Web Client

This version unsets HTTP header C<Accept-Encoding> for any web client
if the HTTP header C<Range> is presented within the request.

=head1 DEPENDENCIES

This module requires these other modules and libraries:

   Apache::Constants;
   Apache::Log;
   Apache::URI;

which come bandled with C<mod_perl>.

=head1 AUTHOR

Slava Bizyayev E<lt>slava@cpan.orgE<gt> - Freelance Software Developer & Consultant.

=head1 COPYRIGHT AND LICENSE

I<Copyright (C) 2002 Slava Bizyayev. All rights reserved.>

  This package is free software.
  You can use it, redistribute it, and/or modify it under the same terms as Perl itself.
  The latest version of this module can be found on CPAN.

=head1 SEE ALSO

C<mod_perl> at F<http://perl.apache.org>

C<Apache::Dynagzip> at F<http://search.cpan.org/author/SLAVA/>

Michael Schroepl's Web Site at F<http://www.schroepl.net/projekte/mod_gzip/browser.htm>

=cut


=head1 NAME

LedgerSMB::old_code - dispatching from new code to old code

=head1 SYNPOSIS

 return LedgerSMB::old_code::dispatch('ar.pl', 'print', $request);

 return LedgerSMB::old_code::dispatch('ar.pl', 'print', { id => 1, ... });



 use LedgerSMB::old_code qw(dispatch);

 return dispatch('ar.pl', 'print', $request);


=head1 FUNCTIONS

=over

=cut

package LedgerSMB::old_code;


use strict;
use warnings;
use CGI::Parse::PSGI qw(parse_cgi_output);
use IO::File;
use LedgerSMB::Form;
use POSIX 'SEEK_SET';

use base qw(Exporter);
our @EXPORT_OK = qw(dispatch);


# make sure the package exists after 'use'-ing this module:

# We're doing dodgy things in the next line,
# but we're doing so deliberately; don't fail the criticism:
# It'll go away when we eliminate old code
package lsmb_legacy {  ## no critic
    our $form;
    our $locale;
    our %myconfig;
};


=item dispatch($script, $entrypoint, $form_keys [, entrypoint args... ])

Wraps a "call" to old code, returning a PSGI triplet for the response.

=cut

sub dispatch {
    my $script = shift;
    my $entrypoint = shift;
    my $args = shift;

    my $stdout = IO::File->new_tmpfile;
    if (my $cpid = fork()) {
        waitpid $cpid, 0;
        seek($stdout, 0, SEEK_SET)
            or croak("Can't seek stdout handle: $!");

        return parse_cgi_output($stdout);
    }
    else {
        local *STDOUT = $stdout;
        $lsmb_legacy::form = Form->new();
        $lsmb_legacy::form->{$_} = $args->{$_} for (keys %$args);
        $lsmb_legacy::locale = $LedgerSMB::App_State::Locale;
        %lsmb_legacy::myconfig = %$LedgerSMB::App_State::User;
        {
            no strict;
            no warnings 'redefine';

            # Note that we're only loading this code *after* the fork,
            # so, we're only ever "polluting" the namespaces of the
            # child Perl process which we'll ditch right after.
            do "old/bin/$script";
        }
        if (ref $entrypoint eq "CODE") {
            $entrypoint->(@_);
        }
        else {
            &${"lsmb_legacy::$entrypoint"}($lsmb_legacy::form,
                                           $lsmb_legacy::locale);
        }
        exit;
    }
}

=back

=head1 Copyright (C) 2016, The LedgerSMB core team.

This file is licensed under the Gnu General Public License version 2, or at your
option any later version.  A copy of the license should have been included with
your software.

=cut

1;

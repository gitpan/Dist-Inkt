package Dist::Inkt::Role::WriteMetaYML;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.003';

use Moose::Role;
use namespace::autoclean;

after BUILD => sub {
	my $self = shift;
	unshift @{ $self->targets }, 'MetaYML';
};

sub Build_MetaYML
{
	my $self = shift;
	my $file = $self->targetfile('META.yml');
	$file->exists and return $self->log('Skipping %s; it already exists', $file);
	$self->log('Writing %s', $file);
	$self->metadata->save($file, { version => '1.4' });
}

1;

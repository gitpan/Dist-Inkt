package Dist::Inkt::Role::WriteMetaJSON;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.010';

use Moose::Role;
use namespace::autoclean;

after BUILD => sub {
	my $self = shift;
	unshift @{ $self->targets }, 'MetaJSON';
};

sub Build_MetaJSON
{
	my $self = shift;
	my $file = $self->targetfile('META.json');
	$file->exists and return $self->log('Skipping %s; it already exists', $file);
	$self->log('Writing %s', $file);
	$self->rights_for_generated_files->{'META.json'} ||= [
		$self->_inherited_rights
	] if $self->DOES('Dist::Inkt::Role::WriteCOPYRIGHT');
	$self->metadata->save($file, { version => '2' });
}

1;

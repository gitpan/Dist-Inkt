package Dist::Inkt::Profile::TOBYINK;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.003';

use Moose;

extends 'Dist::Inkt';

with qw(
	Dist::Inkt::Role::ReadMetaDir
	Dist::Inkt::Role::ProcessDOAP
	Dist::Inkt::Role::ProcessDOAPDeps
	Dist::Inkt::Role::CopyFiles
	Dist::Inkt::Role::CopyStandardDocuments
	Dist::Inkt::Role::MetaProvides
	Dist::Inkt::Role::MetaProvidesScripts
	Dist::Inkt::Role::WriteMakefilePL
	Dist::Inkt::Role::WriteMetaJSON
	Dist::Inkt::Role::WriteMetaYML
	Dist::Inkt::Role::WriteMetaTTL
	Dist::Inkt::Role::WriteChanges
	Dist::Inkt::Role::WriteCOPYRIGHT
	Dist::Inkt::Role::WriteCREDITS
	Dist::Inkt::Role::WriteLICENSE
	Dist::Inkt::Role::WriteREADME
	Dist::Inkt::Role::SignDistribution
);

1;
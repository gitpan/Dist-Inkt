package Dist::Inkt::Role::WriteMakefilePL;

our $AUTHORITY = 'cpan:TOBYINK';
our $VERSION   = '0.008';

use Moose::Role;
use Types::Standard -types;
use Data::Dump 'pp';
use namespace::autoclean;

sub DYNAMIC_CONFIG_PATH () { 'meta/DYNAMIC_CONFIG.PL' };

has has_shared_files => (
	is      => 'ro',
	isa     => Bool,
	lazy    => 1,
	builder => '_build_has_shared_files',
);

sub _build_has_shared_files
{
	my $self = shift;
	!! $self->sourcefile('share')->is_dir;
}

has needs_conflict_check_code => (
	is      => 'ro',
	isa     => Bool,
	lazy    => 1,
	builder => '_build_needs_conflict_check_code',
);

sub _build_needs_conflict_check_code
{
	my $self = shift;
	!!grep {
		exists $self->metadata->{prereqs}{$_}
		and exists $self->metadata->{prereqs}{$_}{conflicts}
		and !!scalar keys %{ $self->metadata->{prereqs}{$_}{conflicts} }
	} qw( configure build runtime test develop );
}

after PopulateMetadata => sub {
	my $self = shift;
	$self->metadata->{prereqs}{configure}{requires}{'ExtUtils::MakeMaker'} = '6.17'
		if !defined $self->metadata->{prereqs}{configure}{requires}{'ExtUtils::MakeMaker'};
	$self->metadata->{prereqs}{configure}{requires}{'File::ShareDir::Install'} = '0.02'
		if $self->has_shared_files
		&& !defined $self->metadata->{prereqs}{configure}{requires}{'File::ShareDir::Install'};
	$self->metadata->{prereqs}{configure}{requires}{'CPAN::Meta::Requirements'} = '2.000'
		if $self->needs_conflict_check_code;
	$self->metadata->{dynamic_config} = 1
		if $self->sourcefile(DYNAMIC_CONFIG_PATH)->exists;
};

after BUILD => sub {
	my $self = shift;
	unshift @{ $self->targets }, 'MakefilePL';
};

sub Build_MakefilePL
{
	my $self = shift;
	my $file = $self->targetfile('Makefile.PL');
	$file->exists and return $self->log('Skipping %s; it already exists', $file);
	$self->log('Writing %s', $file);
	
	chomp(
		my $dump = pp( $self->metadata->as_struct({version => '2'}) )
	);

	my $dynamic_config = do
	{
		my $dc = $self->sourcefile(DYNAMIC_CONFIG_PATH);
		$dc->exists ? "\ndo {\n${\ $dc->slurp_utf8 }\n};" : '';
	};

	$self->rights_for_generated_files->{'Makefile.PL'} ||= [
		'Copyright 2013 Toby Inkster.',
		"Software::License::Perl_5"->new({ holder => 'Toby Inkster', year => '2013' }),
	] if $self->DOES('Dist::Inkt::Role::WriteCOPYRIGHT') && !$dynamic_config;

	my $share = '';
	if ($self->has_shared_files)
	{
		$share = "\nuse File::ShareDir::Install;\n"
			. "install_share 'share';\n"
			. "{ package MY; use File::ShareDir::Install qw(postamble) };\n";
	}
	
	my $conflict_check = $self->needs_conflict_check_code ? $self->conflict_check_code : '';
	
	my $makefile = do { local $/ = <DATA> };
	$makefile =~ s/%%%METADATA%%%/$dump/;
	$makefile =~ s/%%%SHARE%%%/$share/;
	$makefile =~ s/%%%DYNAMIC_CONFIG%%%/$dynamic_config/;
	$makefile =~ s/%%%CONFLICT_CHECK%%%/$conflict_check/;
	$file->spew_utf8($makefile);
}

sub conflict_check_code
{
	<<'CODE'
for my $stage (keys %{$meta->{prereqs}})
{
	my $conflicts = $meta->{prereqs}{$stage}{conflicts} or next;
	require CPAN::Meta::Requirements;
	$conflicts = 'CPAN::Meta::Requirements'->from_string_hash($conflicts);
	
	for my $module ($conflicts->required_modules)
	{
		eval "require $module" or next;
		my $installed = eval(sprintf('$%s::VERSION', $module));
		$conflicts->accepts_module($module, $installed) or next;
		
		my $message = "\n".
			"** This version of $meta->{name} conflicts with the version of\n".
			"** module $module ($installed) you have installed.\n";
		die($message . "\n" . "Bailing out")
			if $stage eq 'build' || $stage eq 'configure';
		
		$message .= "**\n".
			"** It's strongly recommended that you update it after\n".
			"** installing this version of $meta->{name}.\n";
		warn("$message\n");
	}
}
CODE
}

1;

__DATA__
use strict;
use ExtUtils::MakeMaker 6.17;

my $EUMM = 'ExtUtils::MakeMaker'->VERSION;

my $meta = %%%METADATA%%%;

my %dynamic_config;%%%DYNAMIC_CONFIG%%%
%%%CONFLICT_CHECK%%%
my %WriteMakefileArgs = (
	ABSTRACT   => $meta->{abstract},
	AUTHOR     => ($EUMM >= 6.5702 ? $meta->{author} : $meta->{author}[0]),
	DISTNAME   => $meta->{name},
	VERSION    => $meta->{version},
	EXE_FILES  => [ map $_->{file}, values %{ $meta->{x_provides_scripts} || {} } ],
	NAME       => do { my $n = $meta->{name}; $n =~ s/-/::/g; $n },
	%dynamic_config,
);

$WriteMakefileArgs{LICENSE} => $meta->{license}[0] if $EUMM >= 6.3001;

sub deps
{
	my %r;
	for my $stage (@_)
	{
		for my $dep (keys %{$meta->{prereqs}{$stage}{requires}})
		{
			my $ver = $meta->{prereqs}{$stage}{requires}{$dep};
			$r{$dep} = $ver if !exists($r{$dep}) || $ver >= $r{$dep};
		}
	}
	\%r;
}

my ($build_requires, $configure_requires, $runtime_requires, $test_requires);
if ($EUMM >= 6.6303)
{
	$WriteMakefileArgs{BUILD_REQUIRES}     ||= deps('build');
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{TEST_REQUIRES}      ||= deps('test');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime');
}
elsif ($EUMM >= 6.5503)
{
	$WriteMakefileArgs{BUILD_REQUIRES}     ||= deps('build', 'test');
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime');	
}
elsif ($EUMM >= 6.52)
{
	$WriteMakefileArgs{CONFIGURE_REQUIRES} ||= deps('configure');
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('runtime', 'build', 'test');	
}
else
{
	$WriteMakefileArgs{PREREQ_PM}          ||= deps('configure', 'build', 'test', 'runtime');	
}

{
	my $minperl = delete $WriteMakefileArgs{PREREQ_PM}{perl};
	exists($WriteMakefileArgs{$_}) && delete($WriteMakefileArgs{$_}{perl})
		for qw(BUILD_REQUIRES TEST_REQUIRES CONFIGURE_REQUIRES);
	if ($minperl and $EUMM >= 6.48)
	{
		$WriteMakefileArgs{MIN_PERL_VERSION} ||= $minperl;
	}
	elsif ($minperl)
	{
		die "Need Perl >= $minperl" unless $] >= $minperl;
	}
}

sub FixMakefile
{
	return unless -d 'inc';
	my $file = shift;
	
	local *MAKEFILE;
	open MAKEFILE, "< $file" or die "FixMakefile: Couldn't open $file: $!; bailing out";
	my $makefile = do { local $/; <MAKEFILE> };
	close MAKEFILE or die $!;
	
	$makefile =~ s/\b(test_harness\(\$\(TEST_VERBOSE\), )/$1'inc', /;
	$makefile =~ s/( -I\$\(INST_ARCHLIB\))/ -Iinc$1/g;
	$makefile =~ s/( "-I\$\(INST_LIB\)")/ "-Iinc"$1/g;
	$makefile =~ s/^(FULLPERL = .*)/$1 "-Iinc"/m;
	$makefile =~ s/^(PERL = .*)/$1 "-Iinc"/m;
	
	open  MAKEFILE, "> $file" or die "FixMakefile: Couldn't open $file: $!; bailing out";
	print MAKEFILE $makefile or die $!;
	close MAKEFILE or die $!;
}
%%%SHARE%%%
my $mm = WriteMakefile(%WriteMakefileArgs);
FixMakefile($mm->{FIRST_MAKEFILE} || 'Makefile');
exit(0);


#! /usr/bin/env perl

use strict;
use warnings;

use Data::Dumper;
use File::Path       qw( make_path );
use File::Copy  qw( copy move);
use File::Find::Rule qw( );
use Cwd qw(getcwd);
use File::Basename;
use File::Copy ();
use File::Remove ();
use File::Basename;
use File::Find;
use File::Spec;
use Getopt::Long   qw( GetOptions );
use Cwd;

##TO CHECK THE USAGE AT COMMAND LINE ARGUMENTS##
sub usage {
   if (@_) {
      my ($msg) = @_;
      chomp($msg);
      print(STDERR "$msg\n");
   }

   my $prog = basename($0);
   print(STDERR "$prog --help for usage\n");
   exit(1);
}

sub help {
   my $prog = basename($0);
   print(STDERR "$prog [options] -output output_dir\n");
   print(STDERR "$prog --help\n");
   exit(0);
}
###RENAMING THE FILES
sub runDir($$);
sub runDir($$) {
    my $prefix = shift @_;
    my $dir = shift @_;
    #print $dir;
    opendir(DIR, $dir) or die $!;
    my @entries = readdir(DIR);    
    #print @entries,"\n";
    close(DIR);
    foreach my $file (@entries) {
       next if ($file =~ /^\.+$/);
        if ( -d $dir . '/' . $file) {
            runDir( $file .'_', $dir . '/' . $file);
        } elsif ( ( -f $dir . '/' . $file ) && ( $file =~ /\.config$/ ) && ($file !~ /^$prefix/)) {
            my $suffix = $file;
            $suffix=~s{\A[^.]*}{}xms;
            rename $dir . '/' . $file, $dir . '/' .$prefix . $suffix ;
        }
        
    }
}
runDir('',$output_dir);
##GETTING INPUT/OUTPUT FILE FROM COMMAND LINE ARGUMENTS##

GetOptions(
    'help|h|?' => \&help,
    'prjroot=s' => \my $base_dir,
    'outdir=s' => \my $output_dir,
    'mapfile=s' => \my $mapfile,
)
    or usage();

##CREATING THE DIRECTORIES FROM COMMAND LINE ARGUMENTS##
mkdir $output_dir ;

my $input_dir = get_input_dir( $base_dir );

sub get_input_dir {
    my ( $base_dir ) = @_;

    my $fn = File::Spec->catfile( $base_dir, 'project.config' );
    my $input_dir;
    open ( my $fh, '<', $fn ) or die "Could not open file '$fn': $!";
    while ( <$fh> ) {
        chomp;
        if (/^REVISION_LOCATION:\s*(\S+)/) {
            $input_dir = $1;
            last;
        }
    }
    close $fh;
    die "Could not find revision location!" if !defined $input_dir;
    return $input_dir;
}

my @input_dirs = ( $input_dir );
if ( $input_dir =~ /^\.\./ ) {
    @input_dirs = find_input_dirs( $input_dir );
}

sub find_input_dirs {
    my ( $dir ) = @_;
    $dir =~ s/^\.\.//;
    
    my @dirs = File::Find::Rule->new->directory
      ->exec( sub { ($_[1] =~ /\Q$dir\E/) ? 1 : 0 } )->in('/');
    return @dirs;
}

for my $input_dir ( @input_dirs ) {
    copy_config_files( $input_dir, $output_dir );
}

sub copy_config_files {
    my ( $input_dir, $output_dir ) = @_;
    
    ##COPYING THE CONFIG FILES FROM SOURCE TO DESTINATION### 

    my %created;
    for my $in (
        File::Find::Rule
        ->maxdepth(5)
        ->file()
        ->prune()
        ->name(qr/^[^.].*\.config$/)
        ->in($input_dir)
    ) {
        my $match_file = substr($in, length($input_dir) + 1); 
        my ($match_dir) = $match_file =~ m{^(.*)/} ? $1 : '.';
        my $out_dir = $output_dir . '/' . $match_dir;
        my $out     = $output_dir . '/' . $match_file;
        make_path($out_dir) if !$created{$out_dir}++;
        copy($in, $out);
    }
}

##TO RENAME DIRECTORIES AND RENAME THE CONTENTS OF THE .CONFIG FILES AS PER MATCHING WITH MAPFILE.TXT CONTENTS##
my $name_map = read_map( $mapfile );
my ($regex) = map {qr /\b(?:$_)\b/ } join '|', map {quotemeta} keys %$name_map;

my $top_dir = $output_dir;

rename_dirs( $top_dir, $name_map, $regex );
sub rename_dirs {
    my ( $top_dir, $name_map, $regex ) = @_;
    opendir (my $dh, $top_dir) or die "Can't open $top_dir: $!";
    my $save_dir = getcwd();
    chdir $top_dir;
    while (my $name = readdir $dh) {
        next if ($name eq '.') or ($name eq '..'); 
        if ( ( -d $name ) && ( exists $name_map->{$name} ) ) {
            my $new_name = $name_map->{$name};
            rename_file_or_dir( $name, $new_name );
            $name = $new_name;            
        }       
        elsif ( -f $name ) {
            when_config_file_rename_and_modify_it( $name, $name_map, $regex );
        }
        else
        {
         #print "  --> is not a directory", "\n";
         }

        if ( -d $name) { 
            
            rename_dirs( $name, $name_map, $regex );
            
            } 
    }
    chdir $save_dir;
}


sub when_config_file_rename_and_modify_it {
    my ( $name, $name_map, $regex ) = @_;
    if (( my $base_name = $name) =~ s/\.config$// ) {
        if ( $name_map->{$base_name} ) {
            my $new_name = $name_map->{$base_name} . '.config';
            rename_file_or_dir( $name, $new_name );
            $name = $new_name;
        }
        change_file( $name, $name_map, $regex );
    }
}

sub change_file {
    my ( $fn, $map, $regex ) = @_;
    open ( my $fh, '<', $fn ) or die "Could not open file '$fn': $!";
    my $str = do { local $/; <$fh> };
    close $fh;
    my $num_replacements = $str =~ s/($regex)/$map->{$1}/ge;
    if ( $num_replacements ) {
        write_new_file( $fn, \$str );
    }
}

sub write_new_file {
    my ( $fn, $str ) = @_;
    open ( my $fh, '>', $fn ) or die "Could not open file '$fn': $!";
    print $fh $$str;
    close $fh;
}

sub rename_file_or_dir {

    my ( $name, $new_name ) = @_;
    File::Copy::move( $name, $new_name )
        or die "Could not rename '$name' as '$new_name': $!";
        #print $name;
}

sub read_map {
    my ( $fn ) = @_;

    my %name_map;

    open( my $fh, '<', $fn ) or die "Could not open file '$fn': $!";
    while( my $line = <$fh> ) {
        chomp $line;
        my @fields = split /:/, $line;
       # print @fields;
        if ( @fields == 3 ) {
            $name_map{$fields[2]} = $fields[1];
        }
    }
    close $fh;
    return \%name_map;
}
sub file_filter
{
my $location=shift;

open LOGFILE, $location;

my $max_id;

while (<LOGFILE>) {
    if (/rev(\d+)/) {
        
            $max_id = $1;
            
            
        } else {
            $max_id = $1 if ($1 > $max_id);
            
        }
    }
    close LOGFILE;
}


file_filter($output_dir);

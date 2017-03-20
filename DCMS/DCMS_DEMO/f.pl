#!/usr/local/bin/perl
use strict;
use warnings 'all';
use CGI qw(:all);
#generate the user file arguments

use File::Path       qw( make_path );
use File::Copy  qw( copy move);
use File::Find::Rule qw( );
use File::Remove();
use Cwd qw(getcwd);
use File::Basename;
use File::Copy ();
use File::Remove();
use File::Basename;
use File::Find;
use File::Spec;
use Getopt::Long   qw( GetOptions );

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

##GETTING INPUT/OUTPUT FILE FROM COMMAND LINE ARGUMENTS##

GetOptions(
    'help|h|?' => \&help,
    'prjroot=s' => \my $input_dir,
    'outdir=s' => \my $output_dir,
    'mapfile=s' => \my $mapfile,
)
    or usage();

##CREATING THE DIRECTORIES FROM COMMAND LINE ARGUMENTS##
mkdir $output_dir ;

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
##TO RENAME THE DIRECTORIES AS PER MAPFILE.TXT CONTENTS
=d
my $dir_map = read_map($mapfile);
my $top_dir=$output_dir;
rename_dirs( $top_dir, $dir_map );
sub rename_dirs {
    my ( $top_dir, $dir_map ) = @_;
    opendir (my $dh, $top_dir) or die "Can't open $top_dir: $!";
    my $save_dir = getcwd();
    chdir $top_dir;
    while (my $name = readdir $dh) {
    #print $name,"\n";
        next if ($name eq '.') or ($name eq '..'); 
        if ( exists $dir_map->{$name} ) {
            my $new_name = $dir_map->{$name};
            File::Copy::move( $name, $new_name )
                or die "Could not rename '$name' as '$new_name': $!";
            $name = $new_name;
        }
        rename_dirs( $name, $dir_map ) if -d $name;
        
    }
    chdir $save_dir;
}
##SUB ROUTINE TO READ THE TEXT FILE FROM COMMAND LINE ARGUMENTS##
sub read_map {
    my ( $fn ) = @_;
    my %dir_map;
    open( my $fh, '<', $fn ) or die "Could not open file '$fn': $!";
    while( my $line = <$fh> ) {
    chomp $line;
    my @fields = split /:/, $line;
    if ( @fields == 3 ) {
        $dir_map{$fields[2]} = $fields[1];
        }
    }
    close $fh;
    return \%dir_map;
}
=cut
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
        #print $name,"\n";
        if ( ( -d $name ) && ( exists $name_map->{$name} ) ) {
            #print $name;
            my $new_name = $name_map->{$name};
            #print $new_name; 
            rename_file_or_dir( $name, $new_name );
            $name = $new_name;            
            #print $name;
        }
        
        elsif ( -f $name ) {
            if (( my $base_name = $name) =~ s/\.config$// ) {
                if ( $name_map->{$base_name} ) {
                    my $new_name = $name_map->{$base_name} . '.config';
                  #  print $new_name;
                    rename_file_or_dir( $name, $new_name );
                    change_file( $mapfile, $name_map, $regex );
                }
            }
        }
        rename_dirs( $name, $name_map, $regex ) if -d $name;
    }
    chdir $save_dir;
}

sub change_file {
    my ( $fn, $map, $regex ) = @_;
    print $fn;
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
    print $fh $str;
    close $fh;
}

sub rename_file_or_dir {
    my ( $name, $new_name ) = @_;
    File::Copy::move( $name, $new_name )
        or die "Could not rename '$name' as '$new_name': $!";
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

##RENAME THE FILES WITH ITS DIRECTORIES NAME FROM THE FOLDERS NAME##

    my $input_file_dir = $output_dir;
    sub process_file 
    {
      my $dir_name = (File::Spec -> splitdir ($File::Find::dir))[-1];
      my $file_name = basename $_;
      my $extension = ($file_name =~ m/([^.]+)$/)[0];        
      if ( -f $_ ) 
      {
        rename $_, "$dir_name.$extension";
      }
    }
    finddepth { 'wanted' => \&process_file, 'no_chdir' => 0 }, $input_file_dir;
    
##PROCESSING AND REMOVING THE UNWANTED DIRECTORIES##
sub ProcessDirectory{
    my ($workdir) = shift;
    my $mask = $workdir . '/*';
    my @dirs = grep { -d } glob $mask;
    foreach my $d (@dirs)
    {
        ProcessDirectory($d);
        my $dirname = basename($d);
        if ($dirname =~ /^temp*/)
        {
          my $filemask = $d . '/*';
          unlink glob $filemask;
          rmdir $d;          
        }
    }
}
ProcessDirectory($output_dir);

##REMOVE TASK.CONFIG FROM ALL DIRECTORIES##
sub DelTaskFiles{
    my ($workdir) = shift;
    my $mask = $workdir . '/*';
    my @files1 = glob $mask;
    foreach my $f (@files1)
    {
        if(-d $f)
        {
        DelTaskFiles($f);
        }
        else
        {
        my $filename1 = basename($f);     
            if ($filename1 =~ /^task*/)
            {
                unlink $f;
            }      
       }
   }
}
DelTaskFiles($output_dir);

my @text_files = glob('*.html');  # Immediate files only

mkdir $output_dir."/"."summary" if not -d "summary";   # Make this dir before the loop
for my $file ( @text_files ) {
    next unless -f $file;              # Make sure this is a file you want to copy!
    #
    # No need for 'dirname' and 'basename' with '*.txt' glob
    #
    if ( not copy $file, 'summary' ) { # Check the outcome of this command.
        warn qq(Could not copy file "$file" to "summary".);
    }
}

##HTML CONVERSION##
my @files = File::Find::Rule->file
                            ->name('*.config')
                            ->prune
                            ->in($output_dir);
                                                       
foreach my $file (@files) 
{
    my ($name, $root, $ext) = $file =~ m|(.*)/(.*)\.(.*)|;   
   # print $name;
    my $outfile = "$name/$root.html";
    #print $outfile;
    #print "Found: $name/$root", '.', $ext, ". Write: $outfile","\n";    
    open my $fh_out, '>', $outfile or die "Can't open $outfile: $!","\n";
    my $head = "
<!doctype html>
<html lang=\"en\"> 
<head> <meta charset=\"utf-8\"> <title>DCMS_CHECKLIST</title><tr><td></td></tr> </head> 
<body>
<table>
<th>SL.NO</th><th>CHECKLIST ITEM</th><th>VALUE</th><th>COMMENTS</th><th>CONFIRMATION</th>
<style>
.bold {
  font-weight: bold;
}
.bold td
{
border: 0px;
}
table, th, td {
    border: 1px solid black;
}
</style>";
    print $fh_out $head ;   # write the header
    open my $fh, '<', $file or die "Can't open $file: $!";
    while (my $line=<$fh>) {
    chomp $line;
    for($line)
    {    
    s/\&//g;
    s/[\\\_\@\_]//g;
    s/COMMENT//g;
    }
    my @data = split /:/, $line;
    my $class = $data[0] ? 'normal' : 'bold';  
   # print $data[0],"\n";
    #print $HTML qq[<tr class="$class"><td>] . join('</td><td>', split(/:/,$line)) . "</td></tr>\n";
    #print $fh_out qq[<tr class="$class"><td>] . join('</td><td>', split(/:/,$line)) . "</td></tr>\n";
    #print $fh_out qq[<tr class="$class"><td>] . join('</td><td>', split(/:/,$line)) . "</td></tr>\n";   
    print $fh_out qq[<tr class="$class">];
    #my  $href="http://ipdccad.spd.analog.com/cadapps/dev/adikb/dcms_checklist/$root";
    my $href="https://confluence.analog.com/display/ADIKDB/$root";
    my $check=0;
    my $dolink=$data[0] !~ m/[\=\%]/;
    for my $word(@data){ 
    $check++;
    print $fh_out '<td>';
    if($check==1 && $dolink ) {
         print $fh_out '<a href="'.$href.'" >'.$word.'</a>';   
         }
      else { print $fh_out $word;} 
      print $fh_out '</td>';
      }
      }
      
}

use Cwd;



my $source_dir = $input_dir;
my $dest_dir   = $output_dir ;
find ( sub {
   return unless  /\.html/;   #We want files only
   make_path "$dest_dir/$File::Find::dir" 
       unless -d "$dest_dir/$File::Find::dir";
   copy "$_", "$dest_dir/$File::Find::dir"
       or die qq(Can't copy "$File::Find::name" to "$dest_dir/$File::Find::dir");
}, ".");
   


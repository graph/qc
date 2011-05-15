#!/usr/bin/perl
use strict;
# reduce repetitive stuff in c++

# get an array of all files and sub files of given filetype
sub AllFiles  {
        my ($filetype) = @_;
        my @files;
        my $filtered = [];
        @files = split("\n", `find ./ -type f`);

        foreach(@files){
                if($_ =~ /^\.\/+(.*\.$filetype)$/){
                        push (@$filtered, $1);
                }
        }
        return $filtered;
}



sub loadFile {
	my ($file) = @_;
	my ($fh);
	if(!(open($fh, "<$file"))){
		print("could not open $file\n");
		return 0;
	}
	
	my $lines = [];
	while(<$fh>){
		chomp $_;
		push @$lines, $_;
	}
	close($fh);
	return $lines;
}
	
sub OKToRemake {
	my ($file) = @_;
	my $fh;
	if(!(open($fh, "<$file"))){
		print("could not open $file\n");
		return 0;
	}
	
	my ($line_start, $line_end);
	my ($line_num);
	$line_start = 0;
	$line_end = 0;
	
	$line_num =0;
	while(<$fh>){
		if($_ =~ m/^\#pragma\s+qc start\s*/){
			$line_start = $line_num;
		}
		if($_ =~ m/^\#pragma\s+qc end\s*/){
			$line_end = $line_num;
			close($fh);
			return [$line_start, $line_end];
		}
		$line_num++;

	}
	close($fh);
	return 0;
}
sub dofile {
	my ($cppfile, $hfile) = @_;
	my $lines;
	print "Processing $cppfile/$hfile\n";
	$lines = OKToRemake($hfile);
	my $cfh;
	open $cfh, "<$cppfile" or die "Could not open $cppfile";
	
	my $function;
	my $list = [];
	while(<$cfh>){
		chomp $_;
		if($_ =~ m/^(.*)\scc\s(.*)$/){
			$function = "$1 $2";
			if($function =~ m/(.*?)\s*\{\s*/){
				$function = $1;
			}
			if($function =~ m/^#/){
				next;
			}
			
			# add to our list
			push @$list, $function;
		}
	}
	
	close($cfh);
	my $hfile_lines;
	$hfile_lines = loadFile($hfile);

	my $hfh;
	open ($hfh, ">$hfile") or die "Could not open $hfile for outputing";
	my($i);
	

	
	my $output = [];
	
	for($i = 0; $i <= $$lines[0]; $i++){
		print $hfh $$hfile_lines[$i] . "\n";

	}
	for($i =0; $i < @$list; $i++){
		print $hfh $$list[$i] . ";\n";
	}
	for($i = $$lines[1]; $i < @$hfile_lines; $i++){
		print $hfh $$hfile_lines[$i] . "\n";

	}
}
sub PreFile {
	my ($file) = @_;
	
	my ($dir, $name, $cpp, $hfile);
	my $lines;
	my $type;
	if($file =~ m/^(.*)\/(.*)\.([^\.]+)$/){
		$dir = $1;
		$name = $2;
		$type = $3;
		$cpp = "$name.$type";
		$hfile = "$name.h";
		
		$lines = OKToRemake("$dir/$hfile");
		if($lines){
			dofile("$dir/$cpp", "$dir/$hfile");
		}
	} elsif ($file =~ m/^([^\/]+)\.([^\.]+)$/){
		$dir = ".";
		$name = $1;
		$type = $2;
		$cpp = "$name.$type";
		$hfile = "$name.h";
		
		$lines = OKToRemake("$dir/$hfile");
		if($lines){
			dofile("$dir/$cpp", "$dir/$hfile");
		} else {
			print "no lines\n";
		}
			
	} else {
		print "Could not match file $file\n";
	}
	
}

my $file;
my $i;
my $filetypes = [];
my $doall=0;
push @$filetypes, "cpp";

for($i = 0; $i < @ARGV; $i++){
	if($ARGV[$i] eq "-f"){
		push @$filetypes, $ARGV[$i+1];
		$i++;
	}
	if($ARGV[$i] eq "--all" or $ARGV[$i] eq "-a"){
		$doall = 1;
	}

}
$file = $ARGV[0];
if($doall){
	# do all of em
	my $files;
	my $type_n;
	for($type_n = 0; $type_n < @$filetypes; $type_n++){
		$files = AllFiles($$filetypes[$type_n]);
		my $i;
		for($i = 0; $i < @$files; $i++){
			PreFile($$files[$i]);
		}
	}
} else {
	PreFile($file);
}

#!/usr/bin/perl
use strict;
use File::Basename;
use File::Spec;

# reduce repetitive stuff in c++
#quick C = qc
our $outdir;

sub abspath {
	my ($path) = @_;
	return File::Spec->rel2abs($path);
}

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

sub equalArrays {
	my ($a, $b) = @_;
	
	if(@$a != @$b){
		return 0;
	}
	my $i;
	for($i = 0; $i < @$a; $i++){
		if($$a[$i] ne $$b[$i]){
			return 0;
		}
	}
	return 1;
}
sub sameFileContents {
	my ($contents, $file) = @_;
	my $fcontents;
	$fcontents = loadFile($file);
	if(!$fcontents) {
		return 0;
	}
	return equalArrays($contents, $fcontents);
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

sub saveFile {
	my ($lines, $file) = @_;
	my $i;
	my $fh;
	my $r;
	$r = open $fh, ">$file";
	if(!$r) { return 0; }
	for($i = 0; $i < @$lines; $i++){
		print $fh $$lines[$i];
		print $fh "\n";
	}
	close $fh;
	print "Saved $file ...\n";
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

# return true when it is a pure header (All qc generated)
sub isQCAll {
    my ($file) = @_;
    my $lines;
	$lines = loadFile($file);
	if(!$lines) {
		return 0;
	}
    if($$lines[0] =~ m/#pragma\s+qc main/){
        return 1;
    }
    return 0;
}

# the new thing to do which generates entire header for you
sub qcAll {
	my ($cppfile, $hfile) = @_;

    my $lines;
    my $gen = [];
	
	my $function;
    my $gl;
	my $list = [];
	my $i;
    

    my $purecopy;
    $lines = loadFile($cppfile);
    if(!$lines){
        print "Could not open $cppfile";
    }
    print "Processing $cppfile ...\n";
    $purecopy = 0;
	
	push @$gen, "#pragma qc main";
	push @$gen, "#pragma once";
	
    for($i = 0; $i < @$lines; $i++){
		my $l;
        $l = $$lines[$i];
        if($purecopy > 0){
            if($l =~ m/^#if/){
                $purecopy++;
            } elsif($l =~ m/^#endif/){
                $purecopy--;
            }
            if($purecopy > 0){
                push @$gen, $l;
            }
            next;
        }
		if($l =~ m/^(.*)\scc\s(.*)$/){
			$function = "$1 $2";
			if($function =~ m/(.*?)\s*\{\s*/){
				$function = $1;
			}
			if($function =~ m/^#/){
				next;
			}
			
			# add to our list
			push @$gen, "$function;";
		} elsif($l =~ m/^\s*cc\s(.*)$/){
			$function = "$1";
			if($function =~ m/(.*?)\s*\{\s*/){
				$function = $1;
			}
			if($function =~ m/^#/){
					next;
			}
			
			# add to our list
			push @$gen, "$function;";
		}
		
		elsif($l =~ m/^#pragma\s+qc\s+class\s+(\S+)\s*\:\s*(\S+)\s*$/){
			# auto put public :)
			$gl = "class $1 : public $2 {\npublic:\ntypedef $2 super;";
			my @a;
			@a = split(/\n/, $gl);
			push @$gen, @a;
		}elsif ($l =~ m/^#pragma\s+qc\s+class\s+(.*)$/){
			$gl = $1;
			$gl = "class $gl {\npublic:";
			my @a;
			@a = split(/\n/, $gl);
			push @$gen, @a;
		} elsif ($l =~ m/^#pragma\s+qc\s+endc/){
			$gl = "};";
			push @$gen, $gl;
		} elsif ($l =~ m/^#ifdef QC_PURE/){
			$purecopy = 1;
		} elsif ($l =~ m/^#ifndef QC_PURE/){ # so it can be in both places
			$purecopy = 1;
		} 
		#elsif ($l =~ m/^(#include.*$)/){
		#	push @$gen, $1;
		#} elsif ($l =~ m/^(#import.*$)/){
		#	push @$gen, $1;
		#}
            
        
	}
	
	my $hfilelist;
	$hfilelist = loadFile($hfile);
	if(equalArrays($gen, $hfilelist)){
		#dont do anything
		return 1;
	}
	if(!sameFileContents($gen, $hfile)){
		print ("$hfile changed\n");
		saveFile($gen, $hfile);
		if(!sameFileContents($gen, $hfile)){
			print "error::!!!! saved file but its different??";
		}
	} else {
		print "Error: !!! previous thing failed\n";
	}
	return 1;
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

	my($i);

	
	my $output = [];
	
	for($i = 0; $i <= $$lines[0]; $i++){
		push @$output, $$hfile_lines[$i];
		#print $hfh $$hfile_lines[$i] . "\n";

	}
	for($i =0; $i < @$list; $i++){
		push @$output, $$list[$i] . ";";
		#print $hfh $$list[$i] . ";\n";
	}
	for($i = $$lines[1]; $i < @$hfile_lines; $i++){
		push @$output, $$hfile_lines[$i];
		#print $hfh $$hfile_lines[$i] . "\n";
	}
	if(!sameFileContents($output, $hfile)){
		saveFile($output, $hfile);
	}
}

sub getQCDir {
	my ($startdir) = @_;
	$startdir = abspath($startdir);
	
	while ($startdir && length($startdir) > 0){	
		if(-d "$startdir/qcout"){
			return "$startdir/qcout";
		}
		$startdir = dirname($startdir);
	}
}
sub doqc {
	my ($file, $outdir) = @_;
	my ($cpp, $h);
	my ($name, $dir, $ext) = fileparse($file, "\.[^\.]+\$");
	my $hcode;
	my $cppcode;
	my $code;
	$code = loadFile($file);
	
	$hcode = compileH($code);
	$cppcode = compileCPP($code, $file);
	if(!sameFileContents($hcode, "$outdir/$name.h")){
		saveFile($hcode, "$outdir/$name.h");
	}
	if(!sameFileContents($cppcode, "$outdir/$name.cpp")){
		saveFile($cppcode, "$outdir/$name.cpp");
	}
	
	return 0;
}

sub PreFile {
	my ($file) = @_;
	
	my ($dir, $name, $cpp, $hfile);
	my $lines;
	my $type;
	my $pass;
	
	$pass = 1;
	if($file =~ m/^(.*)\/(.*)\.([^\.]+)$/){
		$dir = $1;
		$name = $2;
		$type = $3;
		$cpp = "$name.$type";
		$hfile = "$name.h";
	} elsif ($file =~ m/^([^\/]+)\.([^\.]+)$/){
		$dir = ".";
		$name = $1;
		$type = $2;
		$cpp = "$name.$type";
		$hfile = "$name.h";
		
		#TODO: Use a pass var instaead of duplicating above

			
	} else {
		print "Could not match file $file\n";
		$pass = 0;
	}
	return 0 if(!$pass);
	if($type eq "qc"){
		print "Preprocessing qc file $dir/$cpp ...\n";
		$outdir = getQCDir($dir);
		if(!$outdir){
			print "Could not find suitable dir for qc output files";
			return -1;
		}
		return doqc("$dir/$cpp", $outdir);
	}
	$lines = OKToRemake("$dir/$hfile");
	if($lines){
		dofile("$dir/$cpp", "$dir/$hfile");
	}
	$lines = isQCAll("$dir/$hfile");
	if($lines){
		qcAll("$dir/$cpp", "$dir/$hfile");
	}
	
}

sub replacements {
	my ($string, $search, $replace) = @_;
	
	my $i;
	for($i = 0; $i < @$search; $i++){
		my $s;
		my $r;
		$s = $$search[$i];
		$r = $$replace[$i];
		$string =~ s/$s/$r/g;
	}
	return $string;
}
sub compileCPP {
	my ($code, $file) = @_;
	my $i;
	my $gen = [];
	my $function_prepend="";
	my $braceLevel;
	my $inClass;
	my $inEnum;
	my $lineNumber;
	my $genSize;
	my $fileName;
	my $dir;
	my $ext;
	my $put;
	
	my $replaceStrings = [];
	my $searchStrings = [];
	
	($fileName, $dir, $ext) = fileparse($file, "\.[^\.]+\$");
	
	$braceLevel = 0;
	$inClass = 0;
	$inEnum = 0;
	$lineNumber = 0;
	push @$gen, "#include \"$fileName" . ".h\"";
	
	my $fullFileName;
	$fullFileName = abspath($file);
	push @$gen, "#" . "line 1 \"$fullFileName\"";
	$genSize = 0;
	for($i = 0; $i < @$code; $i++){
		my $line;
		$line = $$code[$i];
		$lineNumber++;
		$genSize++;
		if(@$gen != $genSize){
			push @$gen, "#" . "line $lineNumber \"$fullFileName\"";
			$genSize = @$gen;
		}
		if(!$inEnum && $line =~ m/(\s*)if\s(.*)$/){
			$put = $1 . "if ($2) {";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
		} elsif ($line =~ m/^(\s*)while\s(.*)$/){
			$put = $1 . "while ($2) {";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
		} elsif ($line =~ m/^(\s*)for\s(.*)$/){
			$put = $1 . "for ($2) {";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
		} elsif($line =~ m/^(\s*)switch\s+(.*)\s*$/){
			$put = $1 . "switch ($2) {";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
		} elsif($line =~ m/^(\s*)case\s+(.*):\s*$/ or $line =~ m/(\s*)case\s+(.*)\s*$/){
			$put = $1 . "case $2:";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
		} elsif($line =~ m/^(\s*)default\s*$/ or $line =~ m/(\s*)default:\s*$/){
			push @$gen, $1 . "default:";
		} elsif($line =~ m/^(\s*)end\s*$/){
			if($inEnum) {
				$inEnum = 0;
			} else {
				push @$gen, "$1}";
			}
		} elsif(!$inEnum && $line =~ m/^(\s*)else(\s*)$/){
			push @$gen, "$1 } else {"; 
		} elsif(!$inEnum && $line =~ m/(.*)\s+(\S+\s*\(.*\))\s*\{\s*$/){
			# its a function
			my $put;
			$put = "$1 $function_prepend" . "$2 {";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
			$braceLevel++;
		} elsif($line =~ m/(.*)\s+([^\(\)\s]+)\s*\{\s*$/) {
			# its a function with ()
			my $put;
			$put = "$1 $function_prepend" . "$2 () {";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
			$braceLevel++;
		} elsif($line =~ m/\{\s*/){
			push @$gen, $line;
			$braceLevel++;
		} elsif($line =~ m/(\s*)\}\s*/){
			push @$gen, $1 . "}";
			$braceLevel--;
		} elsif($line =~ m/^\s*class\s+(\S+)\s*:\s*(\S+)$/){
			$function_prepend = $1 . "::";
			$inClass = 1;
		} elsif($line =~ m/^\s*class\s+(\S+)\s*$/){
			$function_prepend = $1 . "::";
			$inClass = 1;
		} elsif($line =~ m/^\s*endclass/){
			# do nothing
			$function_prepend = "";
			$inClass = 0;
		} elsif($line =~ m/^\s*enum\s*$/){
			$inEnum = 1;
		} elsif($line =~ m/^\s*include\s*(".*")\s*$/){
			# for includeing files
			push @$gen, ""
		} elsif($line =~ m/^\s*include\s*(<.*>)\s*$/){
			# for includeing files
			push @$gen, ""
		} elsif($line =~ /^\s*require\s*(".*")\s*$/){
			# include file thats only in the source but not header
			push @$gen, "#include $1";
		} elsif($line =~ /^\$replace\s+(.*?)\s*=>\s*(.*?)\s*$/){
			push @$replaceStrings, $2;
			push @$searchStrings, $1;
		} elsif($line =~ /^#/){
			# header macro
		} elsif($line =~ /^\$(.*)$/){
			# allow pasthrough custom macros
			push @$gen, "#" . $1;
		} 
		else {
			if(($line =~ m/^\s*$/))
			{
				push @$gen, "$line";
			} else {
				if(!$inClass){
					$line = replacements($line, $searchStrings, $replaceStrings);
					push @$gen, "$line" . ";"; # add a semicolor :)
				} elsif($braceLevel > 0){
					$line = replacements($line, $searchStrings, $replaceStrings);
					push @$gen, "$line" . ";";
				}
			}
		}
	}
	return $gen;
}
sub compileH {
	my ($code) = @_;
	my $i;
	my $gen = [];
	my $function_prepend="";
	my $braceLevel;
	my $inClass;
	my $inEnum;
	my $put;
	my $searchStrings=[];
	my $replaceStrings=[];
	$braceLevel = 0;
	$inClass = 0;
	$inEnum = 0;
	push @$gen, "#pragma once";
	
	for($i = 0; $i < @$code; $i++){
		my $line;
		$line = $$code[$i];
		if($line =~ m/^\s*end\s*$/){
			if($inEnum){
				push @$gen, "// enum ended";

				push @$gen, "};";
				$inEnum = 0;
			}
		}elsif($line =~ m/(.*)\s+(\S+\s*\(.*\))\s*\{\s*$/){
			# its a function
			$put = "$1 " . "$2;";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
			$braceLevel++;
		} elsif($line =~ m/(.*)\s+([^\(\)\s]+)\s*\{\s*$/) {
			# its a function with ()
			$put = "$1 $function_prepend" . "$2 ();";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
			$braceLevel++;
		} elsif($line =~ m/^\s*class\s+(\S+)\s*:\s*(\S+)$/){
			$put = "class $1 : public $2 {public: typedef $2 super;";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
			$inClass = 1;
		} elsif($line =~ m/^\s*class\s+(\S+)\s*$/){
			$put = "class $1 {public:";
			$put = replacements($put, $searchStrings, $replaceStrings);
			push @$gen, $put;
			$inClass = 1;
		} elsif($line =~ m/^\s*include\s*(".*")\s*$/){
			# for includeing files
			push @$gen, "#include $1"
		} elsif($line =~ m/^\s*include\s*(<.*>)\s*$/){
			# for includeing files
			push @$gen, "#include $1"
		} elsif($line =~ m/^\s*endclass/){
			$function_prepend = "";
			$inClass = 0;
			push @$gen, "};";
		} elsif($line =~ m/^\s*\}\s*$/){
			$braceLevel--;
		} elsif($line =~ m/^\s*enum\s*/){
			$inEnum = 1;
			push @$gen, "enum {";
		} elsif($line =~ /^\$replace\s+(.*?)\s*=>\s*(.*?)\s*$/){
			push @$replaceStrings, $2;
			push @$searchStrings, $1;
		} elsif($line =~ /^#/){
			# allow pasthrough custom macros
			# dont print them in header
			push @$gen, $line;
		} elsif($line =~ /^\$(.*)$/){
			# only in cpp macro
		}
		
		else {
			# nothing to do here in header file
			if($line =~ m/^\s*$/){
			} elsif($inEnum){
				$put = "$line,";
				$put = replacements($put, $searchStrings, $replaceStrings);
				push @$gen, ;
			} elsif($inClass && $braceLevel == 0){
				$put = "$line" . ";";
				$put = replacements($put, $searchStrings, $replaceStrings);
				push @$gen, $put;
			}
		}
	}
	return $gen;
}

my $file;
my $i;
my $filetypes = [];
my $doall=0;
push @$filetypes, "cpp";
push @$filetypes, "qc";

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

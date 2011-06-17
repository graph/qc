#!/usr/bin/perl
use strict;
use File::Basename

# reduce repetitive stuff in c++
#quick C = qc
our $outdir;

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
			$gl = "class $1 : public $2 {\npublic:\ntypedef $2 super;\n";
			push @$gen, $gl;
		}elsif ($l =~ m/^#pragma\s+qc\s+class\s+(.*)$/){
           $gl = $1;
           $gl = "class $gl {\npublic:";
           push @$gen, $gl;
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

	my $hfh;
	open ($hfh, ">$hfile") or die "Could not open $hfile for outputing";
	my($i);
	

	for($i = 0; $i < @$gen; $i++){
		print $hfh $$gen[$i] . "\n";

	}
    print $hfh "\n";
    close ($hfh);
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

sub doqc {
	my ($file, $outdir) = @_;
	my ($cpp, $h);
	my ($dir, $name, $ext) = fileparse($file);
	
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
		
		$lines = OKToRemake("$dir/$hfile");
		if($lines){
			dofile("$dir/$cpp", "$dir/$hfile");
		}
        $lines = isQCAll("$dir/$hfile");
        if($lines){
            qcAll("$dir/$cpp", "$dir/$hfile");
        }
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
	if(!$pass)return 0;
	if($type eq "qc"){
		$outdir =  "./qcout";
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


sub compileCPP {
	my ($code) = @_;
	my $i;
	my $gen = [];
	my $function_prepend="";
	
	for($i = 0; $i < @$code; $i++){
		my $line;
		$line = $$code[$i];
		if($line =~ m/(\s*)if\s(.*)$/){
			push @$gen, $1 . "if ($2) {";
		} elsif($line =~ m/^(\s*)end\s*$/){
			push @$gen, "$1}";
		} elsif($line =~ m/^(\s*)else(\s*)$/){
			push @$gen, "$1 } else {"; 
		} elsif($line =~ m/(.*)\s(\S+\s*\(.*\))\{\s*$/){
			# its a function
			push @$gen, "$1 $function_prepend" . "$2 {";
		} elsif($line =~ m/\{\s*/){
			push @$gen, $line;
		} elsif($line =~ m/(\s*)\}\s*/){
			push @$gen, $1 . "}";
		} elsif($line =~ m/^\s*class\s+(\S+)\s*:\s*(\S+)$/){
			$function_prepend = $1 . "::";
		} elsif($line =~ m/^\s*class\s+(\S+)\s*$/){
			$function_prepend = $1 . "::";
		}
		
		else {
			push @$gen, "$line" . ";"; # add a semicolor :)
		}
	}
	return $gen;
}
sub compileH {
	my ($code) = @_;
	my $i;
	my $gen = [];
	my $function_prepend="";
	
	for($i = 0; $i < @$code; $i++){
		my $line;
		$line = $$code[$i];
		if($line =~ m/(.*)\s(\S+\s*\(.*\))\{\s*$/){
			# its a function
			push @$gen, "$1 " . "$2 ;";
		} elsif($line =~ m/^\s*class\s+(\S+)\s*:\s*(\S+)$/){
			$function_prepend = $1 . "::";
			push @$gen, "class $1 : public $2 {public: typedef $2 super;";
		} elsif($line =~ m/^\s*class\s+(\S+)\s*$/){
			$function_prepend = $1 . "::";
			push @$gen, "class $1 {public:";
		}
		
		else {
			push @$gen, "$line" . ";"; # add a semicolor :)
		}
	}
	return $gen;
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

use strict;
# reduce repetitive stuff in c++
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
			print "Found lines\n";
			$line_end = $line_num;
			close($fh);
			return [$line_start, $line_end];
		}
		$line_num++;

	}
	close($fh);
	print "Found no lines\n";
	return 0;
}
sub dofile {
	my ($cppfile, $hfile) = @_;
	my $lines;
	
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
		print $$hfile_lines[$i] . "\n";

	}
	for($i =0; $i < @$list; $i++){
		print $hfh $$list[$i] . ";\n";
	}
	for($i = $$lines[1]; $i < @$hfile_lines; $i++){
		print $hfh $$hfile_lines[$i] . "\n";
		print $$hfile_lines[$i] . "\n";

	}
}
sub PreFile {
	my ($file) = @_;
	
	my ($dir, $name, $cpp, $hfile);
	my $lines;
	if($file =~ m/^(.*)\/(.*)\.cpp$/){
		$dir = $1;
		$name = $2;
		
		$cpp = "$name.cpp";
		$hfile = "$name.h";
		
		$lines = OKToRemake("$dir/$hfile");
		if($lines){
			dofile("$dir/$cpp", "$dir/$hfile");
		}
	} elsif ($file =~ m/^([^\/]+)\.cpp$/){
		$dir = ".";
		$name = $1;
		
		print "file = $name\n";
		$cpp = "$name.cpp";
		$hfile = "$name.h";
		
		$lines = OKToRemake("$dir/$hfile");
		if($lines){
			dofile("$dir/$cpp", "$dir/$hfile");
		} else {
			print "no lines\n";
		}
			
	} else {
		print "Could not match file\n";
	}
	
}

my $file;
$file = $ARGV[0];

print $file;

PreFile($file);

#!/usr/bin/perl

# Copyright 2015 Matt Shannon
# Copyright 2001-2014 Nagoya Institute of Technology, Department of Computer Science
# Copyright 2001-2008 Tokyo Institute of Technology, Interdisciplinary Graduate School of Science and Engineering

# This file is part of hts-demo-en-US-cmudict-aridity.
# See `License` for details of license and warranty.

use autodie qw(:all);
use strict;
no strict "vars";

use File::Path qw(make_path);

$| = 1;

use Carp 'verbose';
$SIG{ __DIE__ } = sub { Carp::confess( @_ ) };

if ( @ARGV < 1 ) {
   print "usage: Training.pl Config.pm\n";
   exit(0);
}

# load configuration variables
require( $ARGV[0] );

# model structure
foreach $set ('cmp', 'dur') {
   $vSize{$set}{'total'}   = 0;
   $nstream{$set}{'total'} = 0;
   $nPdfStreams{$set}      = 0;
   foreach $type ( @{ $ref{$set} } ) {
      $vSize{$set}{$type} = $nwin{$type} * $ordr{$type};
      $vSize{$set}{'total'} += $vSize{$set}{$type};
      $nstream{$set}{$type} = $stre{$type} - $strb{$type} + 1;
      $nstream{$set}{'total'} += $nstream{$set}{$type};
      $nPdfStreams{$set}++;
   }
}

# File locations =========================
# data directory
$datdir = "$prjdir/data";

# experiment directory
$exptDir = "$prjdir/expt";

# utterance id lists
$corpus{'trn'} = "$datdir/corpus-train.lst";
$corpus{'tst'} = "$datdir/corpus-test.lst";
$corpus{'gen'} = "$datdir/corpus-gen.lst";

# model list files
$lst{'mon'} = "$datdir/lists/mono.list";
$lst{'ful'} = "$datdir/lists/full.list";
$lst{'all'} = "$datdir/lists/full_all.list";

# master label files
$mlf{'mon'} = "$datdir/labels/mono.mlf";
$mlf{'ful'} = "$datdir/labels/full.mlf";

# configuration variable files
$cfg{'trn'} = "$exptDir/config/trn.cnf";
$cfg{'tst'} = "$exptDir/config/tst.cnf";
$cfg{'nvf'} = "$exptDir/config/nvf.cnf";
$cfg{'syn'} = "$exptDir/config/syn.cnf";
foreach $type (@cmp) {
   $cfg{$type} = "$exptDir/config/${type}.cnf";
}
foreach $type (@dur) {
   $cfg{$type} = "$exptDir/config/${type}.cnf";
}

# questions about contexts
foreach $set ('cmp', 'dur') {
   foreach $type ( @{ $ref{$set} } ) {
      $qs{$type}     = "$datdir/questions/questions_qst${qnum}.hed";
      $qs_utt{$type} = "$datdir/questions/questions_utt_qst${qnum}.hed";
   }
}

# decision tree clustering settings
foreach $set ('cmp', 'dur') {
   foreach $type ( @{ $ref{$set} } ) {
      $mdl{$type} = "-m -a $mdlf{$type}" if ( $thr{$type} eq '000' );
   }
}

# window files for parameter generation
$windir = "${datdir}/win";
foreach $type (@cmp) {
   for ( $d = 1 ; $d <= $nwin{$type} ; $d++ ) {
      $win{$type}[ $d - 1 ] = "${type}.win${d}";
   }
}
$type                 = 'lpf';
$d                    = 1;
$win{$type}[ $d - 1 ] = "${type}.win${d}";

# global variance files and directories for parameter generation
$gvDir         = "$exptDir/gv";
$gvCorpusDir   = "$gvDir/corpus";

# decision tree clustering settings for context-dependent GV model
foreach $type (@cmp) {
   $gvmdl{$type} = "-m -a $gvmdlf{$type}" if ( $gvthr{$type} eq '000' );
}

# HTS Commands & Options ========================
$HCompV        = "$HCOMPV    -A    -C $cfg{'trn'} -D -T 1 -m ";
$HList         = "$HLIST     -A    -C $cfg{'trn'} -D -T 1 -h -z ";
$HInit         = "$HINIT     -A    -C $cfg{'trn'} -D -T 1 -m 1 -u tmvw    -w $wf ";
$HRest         = "$HREST     -A    -C $cfg{'trn'} -D -T 1 -m 1 -u tmvw    -w $wf ";
$HERest{'trn'} = "$HEREST    -A    -C $cfg{'trn'} -D -T 1 -m 1 -u tmvwdmv -w $wf -t $beam ";
$HERest{'tst'} = "$HEREST    -A -B -C $cfg{'tst'} -D -T 1 -m 0 -u d ";
$HHEd{'trn'}   = "$HHED      -A    -C $cfg{'trn'} -D -p -i ";
$HSMMAlign     = "$HSMMALIGN -A    -C $cfg{'tst'} -D -T 1                        -t $beam -w 1.0 ";
$HMGenS        = "$HMGENS    -A -B                -D -T 1                        -t $beam ";

run_expt();

sub run_expt {
   make_path $exptDir;

   # make config files
   print_time("making config files");
   make_path "$exptDir/config";
   make_config();

   # initialize average model
   make_proto_model( $datdir, "$exptDir/proto", "average" );
   $averageDir = "$exptDir/average";
   get_average_model( "$exptDir/proto", "$averageDir/_cmp_only", "average" );
   add_simple_dur( "$averageDir/_cmp_only", $initdurmean, $initdurvari, $averageDir, "average" );

   # initialize monophone model
   if ($daem) {
      $monoDir = "$exptDir/mono";
      convert_model_clone_average_to_list_mmf( $averageDir, $lst{'mon'}, "mono", $monoDir, "monophone" );

      $monoDir = expectation_maximization_deterministic_annealing( $monoDir, $daem_nIte, $nIte, "monophone" );
   }
   else {
      $monoDir = "$exptDir/mono-init";
      convert_model_clone_average_to_list_sep( $averageDir, $lst{'mon'}, "mono", "$monoDir/_sep", "monophone" );
      initialize_model_from_alignments( "$monoDir/_sep", "monophone" );
      convert_model_list_sep_to_list_mmf( "$monoDir/_sep-init", $monoDir, "monophone" );

      $monoDir = expectation_maximization( $monoDir, $nIte, "monophone" );
   }

   # HSMMAlign (forced alignment (monophone))
   $monoFalDir = fal_on_train_corpus( $monoDir, "monophone" );

   # train global (i.e. non-context-dependent) GV model
   if (!$useGV) {
      $gvCurrDir = "";
   }
   else {
      make_data_gv( $corpus{'trn'}, $gvCorpusDir, $monoFalDir, "GV average" );
      make_proto_model_gv( $gvCorpusDir, "$gvDir/proto", "GV average" );
      get_average_model( "$gvDir/proto", "$gvDir/average", "GV average" );
      $gvAverageDir = "$gvDir/average";

      $gvGlobalDir = "$gvDir/global";
      make_path $gvGlobalDir;
      shell("echo gv > $gvGlobalDir/_mlist_new.lst");
      convert_model_clone_average_to_list_mmf( $gvAverageDir, "$gvGlobalDir/_mlist_new.lst", "none", $gvGlobalDir, "global GV" );
      $gvCurrDir = $gvGlobalDir;
   }

   # HERest (computing test set log probability (monophone))
   eval_model( $monoDir, "", "$datdir/scp/test.scp", "monophone" );

   # decision tree clustering (HHEd, HERest, HHEd)
   $clusDir = repeated_clustering_and_em( $monoDir, 2, $nIte, "clus", 0 );

   # HSMMAlign (forced alignment (1mix))
   fal_on_train_corpus( $clusDir, "1mix" );

   # train context-dependent GV model
   if ($useGV && $cdgv) {
      convert_model_clone_average_to_list_mmf( $gvAverageDir, "$gvCorpusDir/lists/full.list", "full", "$gvDir/cd", "context-dependent GV" );
      $gvClusDir = repeated_clustering_and_em( "$gvDir/cd", 1, 1, "context-dependent GV clus", 1 );
      $gvCurrDir = $gvClusDir;
   }

   # HMGenS & SPTK (training modulation spectrum-based postfilter)
   if ($useMSPF) {
      $mspfModelDir = train_mspf( $clusDir, $monoFalDir, "$datdir/labels/full", "$datdir/speech_params" );
   }

   # generate and synthesize (HHEd, HMGenS, SPTK / STRAIGHT)
   synthesize( $clusDir, $lst{'all'}, "$datdir/scp/gen.scp", "gv", $pgtype, $gvCurrDir, "1mix" );

   # HERest (computing test set log probability (1mix))
   eval_model( $clusDir, $lst{'all'}, "$datdir/scp/test.scp", "1mix" );

   # HHEd (converting mmfs to the HTS voice format)
   if ( !$usestraight ) {
      ( $clusHtsVoiceDir, $clusHtsVoiceFile ) = convert_mmfs_to_hts_voice( $clusDir, $gvCurrDir, "1mix" );
   }

   # hts_engine (synthesizing waveforms using hts_engine)
   if ( !$usestraight ) {
      synth_hts_voice( $clusHtsVoiceFile, "$datdir/scp/gen.scp", "$clusHtsVoiceDir-synth", "1mix" );
   }

   # HERest (semi-tied covariance matrices)
   $stcDir = estimate_semi_tied_cov( $clusDir, "stc" );

   # HSMMAlign (forced alignment (stc))
   if (0) {
      fal_on_train_corpus( $stcDir, "stc" );
   }

   # generate and synthesize (HHEd, HMGenS, SPTK / STRAIGHT)
   synthesize( $stcDir, $lst{'all'}, "$datdir/scp/gen.scp", "gv", 0, $gvCurrDir, "stc" );

   # HERest (computing test set log probability (stc))
   eval_model( $stcDir, $lst{'all'}, "$datdir/scp/test.scp", "stc" );

   # HHEd and HERest (increasing the number of mixture components (1mix -> 2mix))
   $twoMixDir = add_1_mix_comp( $clusDir, "2mix" );
   $twoMixDir = expectation_maximization( $twoMixDir, $nIte, "2mix" );

   # HSMMAlign (forced alignment (2mix))
   fal_on_train_corpus( $twoMixDir, "2mix" );

   # generate and synthesize (HHEd, HMGenS, SPTK / STRAIGHT)
   synthesize( $twoMixDir, $lst{'all'}, "$datdir/scp/gen.scp", "gv", 0, $gvCurrDir, "2mix" );

   # HERest (computing test set log probability (2mix))
   eval_model( $twoMixDir, $lst{'all'}, "$datdir/scp/test.scp", "2mix" );

   print_time("nothing (done)");
}

sub shell {
   my ($command) = @_;
   my ($exit);

   $exit = system($command);

   if ( $exit / 256 != 0 ) {
      die "Error in $command\n";
   }
}

sub print_time {
   my ($message) = @_;
   my ( $hostname, $date, $ruler, $i );

   chomp($hostname = `hostname`);
   chomp($date = `date`);

   $message = "Start $message on $hostname at $date";

   $ruler = '';
   for ( $i = 0 ; $i < length($message) + 2 ; $i++ ) {
      $ruler .= '=';
   }

   print "\n$ruler\n";
   print "$message\n";
   print "$ruler\n\n";
}

# Makes an HTK-style script file, also known as an scp file.
sub make_scp {
   my ( $dirIn, $uttIdsFile, $fileExt, $scpFileOut ) = @_;
   my ( $uttId );

   open( SCP, ">$scpFileOut" ) || die "Cannot open file: $!";
   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      print SCP "$dirIn/$uttId.$fileExt\n";

   }
   close(UTTIDS);
   close(SCP);
}

# sub routine for making training data, labels, scp, list, and mlf for GV
sub make_data_gv {
   my ( $uttIdsFile, $corpusDirOut, $monoFalDir, $tag ) = @_;
   my ( $dataDir, $scpFileOut, $type, $uttId, $str, @arr, $start, $end, $find, $i, $j, $nanCount );

   print_time("making GV data ($tag)");

   make_path "$corpusDirOut/cmp";
   make_path "$corpusDirOut/labels/full";
   make_path "$corpusDirOut/lists";
   make_path "$corpusDirOut/scp";

   $dataDir = "$corpusDirOut/cmp";
   $scpFileOut = "$corpusDirOut/scp/train.scp";

   shell("rm -f $scpFileOut");
   shell("touch $scpFileOut");
   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   open( LST, "> $corpusDirOut/tmp.list" );
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      print "Making data, labels, and scp from $uttId.lab for GV...";
      shell("rm -f $dataDir/tmp.cmp");
      shell("touch $dataDir/tmp.cmp");
      $i = 0;

      foreach $type (@cmp) {
         if ( $nosilgv && @slnt > 0 ) {
            shell("rm -f $dataDir/tmp.$type");
            shell("touch $dataDir/tmp.$type");
            open( F, "$monoFalDir/$uttId.lab" ) || die "Cannot open file: $!";
            while ( $str = <F> ) {
               chomp($str);
               @arr = split( / /, $str );
               $find = 0;
               for ( $j = 0 ; $j < @slnt ; $j++ ) {
                  if ( $arr[2] eq "$slnt[$j]" ) { $find = 1; last; }
               }
               if ( $find == 0 ) {
                  $start = int( $arr[0] * ( 1.0e-7 / ( $fs / $sr ) ) );
                  $end   = int( $arr[1] * ( 1.0e-7 / ( $fs / $sr ) ) );
                  shell("$BCUT -s $start -e $end -l $ordr{$type} < $datdir/speech_params/$uttId.$type >> $dataDir/tmp.$type");
               }
            }
            close(F);
         }
         else {
            shell("cp $datdir/speech_params/$uttId.$type $dataDir/tmp.$type");
         }
         if ( $msdi{$type} == 0 ) {
            shell("cat      $dataDir/tmp.$type                              | $VSTAT -d -l $ordr{$type} -o 2 >> $dataDir/tmp.cmp");
         }
         else {
            shell("$X2X +fa $dataDir/tmp.$type | grep -v '1e+10' | $X2X +af | $VSTAT -d -l $ordr{$type} -o 2 >> $dataDir/tmp.cmp");
         }
         system("rm -f $dataDir/tmp.$type");
         $i += 4 * $ordr{$type};
      }
      $nanCount = `$NAN $dataDir/tmp.cmp`;
      chomp($nanCount);
      if ( length($nanCount) > 0 ) {
         warn "WARNING: omitting bad data from GV model training: utterance $uttId\n";
      }
      else {
         shell("$PERL $datdir/scripts/addhtkheader.pl $sr $fs $i 9 $dataDir/tmp.cmp > $dataDir/$uttId.cmp");
         shell("echo $dataDir/$uttId.cmp >> $scpFileOut");
         open( LAB, "$datdir/labels/full/$uttId.lab" ) || die "Cannot open file: $!";
         $str = <LAB>;
         close(LAB);
         chomp($str);
         while ( index( $str, " " ) >= 0 || index( $str, "\t" ) >= 0 ) { substr( $str, 0, 1 ) = ""; }
         open( LAB, "> $corpusDirOut/labels/full/$uttId.lab" ) || die "Cannot open file: $!";
         print LAB "$str\n";
         close(LAB);
         print LST "$str\n";
      }
      system("rm -f $dataDir/tmp.cmp");
      print "done\n";
   }
   close(LST);
   system("sort -u $corpusDirOut/tmp.list > $corpusDirOut/lists/full.list");
   system("rm -f $corpusDirOut/tmp.list");
   close(UTTIDS);

   # make mlf
   open( MLF, "> $corpusDirOut/labels/full.mlf" ) || die "Cannot open file: $!";
   print MLF "#!MLF!#\n";
   print MLF "\"*/*.lab\" -> \"$corpusDirOut/labels/full\"\n";
   close(MLF);
}

sub make_stc_config {
   my ( $stcBaseFileIn, $cfgFileOut ) = @_;
   my ( $type, $s, $bSize );

   # config file for STC
   open( CONF, ">$cfgFileOut" ) || die "Cannot open file: $!";
   print CONF "MAXSEMITIEDITER = 20\n";
   print CONF "SEMITIEDMACRO   = \"cmp\"\n";
   print CONF "SAVEFULLC = T\n";
   print CONF "BASECLASS = \"$stcBaseFileIn\"\n";
   print CONF "TRANSKIND = SEMIT\n";
   print CONF "USEBIAS   = F\n";
   print CONF "ADAPTKIND = BASE\n";
   print CONF "BLOCKSIZE = \"";

   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         $bSize = $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} / $nblk{$type};
         print CONF "IntVec $nblk{$type} ";
         for ( $b = 1 ; $b <= $nblk{$type} ; $b++ ) {
            print CONF "$bSize ";
         }
      }
   }
   print CONF "\"\n";
   print CONF "BANDWIDTH = \"";
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         $bSize = $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} / $nblk{$type};
         print CONF "IntVec $nblk{$type} ";
         for ( $b = 1 ; $b <= $nblk{$type} ; $b++ ) {
            print CONF "$band{$type} ";
         }
      }
   }
   print CONF "\"\n";
   close(CONF);
}

# sub routine for generating baseclass for STC
sub make_stc_base {
   my ($stcBaseFileOut) = @_;
   my ( $stcBaseName, $type, $s, $class );

   # output baseclass definition
   # open baseclass definition file
   open( BASE, ">$stcBaseFileOut" ) || die "Cannot open file: $!";

   $stcBaseName = `basename $stcBaseFileOut`;
   chomp($stcBaseName);

   # output header
   print BASE "~b \"$stcBaseName\"\n";
   print BASE "<MMFIDMASK> *\n";
   print BASE "<PARAMETERS> MIXBASE\n";

   # output information about stream
   print BASE "<STREAMINFO> $nstream{'cmp'}{'total'}";
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         printf BASE " %d", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
      }
   }
   print BASE "\n";

   # output number of baseclasses
   $class = 0;
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         if ( $msdi{$type} == 0 ) {
            $class++;
         }
         else {
            $class += 2;
         }
      }
   }
   print BASE "<NUMCLASSES> $class\n";

   # output baseclass pdfs
   $class = 1;
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         if ( $msdi{$type} == 0 ) {
            printf BASE "<CLASS> %d {*.state[2-%d].stream[%d].mix[%d]}\n", $class, $nState + 1, $s, 1;
            $class++;
         }
         else {
            printf BASE "<CLASS> %d {*.state[2-%d].stream[%d].mix[%d]}\n", $class, $nState + 1, $s, 1;
            printf BASE "<CLASS> %d {*.state[2-%d].stream[%d].mix[%d]}\n", $class + 1, $nState + 1, $s, 2;
            $class += 2;
         }
      }
   }

   # close file
   close(BASE);
}

# sub routine for generating config files
sub make_config {
   my ( $s, $type );

   # config file for model training
   open( CONF, ">$cfg{'trn'}" ) || die "Cannot open file: $!";
   print CONF "APPLYVFLOOR = T\n";
   print CONF "NATURALREADORDER = T\n";
   print CONF "NATURALWRITEORDER = T\n";
   print CONF "TREEMERGE = F\n";
   print CONF "VFLOORSCALESTR = \"Vector $nstream{'cmp'}{'total'}";
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         print CONF " $vflr{$type}";
      }
   }
   print CONF "\"\n";
   printf CONF "DURVARFLOORPERCENTILE = %f\n", 100 * $vflr{'dur'};
   print CONF "APPLYDURVARFLOOR = T\n";
   print CONF "MAXSTDDEVCOEF = $maxdev\n";
   print CONF "MINDUR = $mindur\n";
   close(CONF);

   # config file for test corpus
   open( CONF, ">$cfg{'tst'}" ) || die "Cannot open file: $!";
   print CONF "NATURALREADORDER = T\n";
   print CONF "NATURALWRITEORDER = T\n";
   print CONF "MAXSTDDEVCOEF = $maxdev\n";
   print CONF "MINDUR = $mindur\n";
   close(CONF);

   # config file for model training (without variance flooring)
   open( CONF, ">$cfg{'nvf'}" ) || die "Cannot open file: $!";
   print CONF "APPLYVFLOOR = F\n";
   print CONF "DURVARFLOORPERCENTILE = 0.0\n";
   print CONF "APPLYDURVARFLOOR = F\n";
   close(CONF);

   # config file for model tying
   foreach $type (@cmp) {
      open( CONF, ">$cfg{$type}" ) || die "Cannot open file: $!";
      print CONF "MINLEAFOCC = $mocc{$type}\n";
      close(CONF);
   }
   foreach $type (@dur) {
      open( CONF, ">$cfg{$type}" ) || die "Cannot open file: $!";
      print CONF "MINLEAFOCC = $mocc{$type}\n";
      close(CONF);
   }
}

# sub routine for generating .hed files for decision-tree clustering
sub make_edfile_state {
   my ( $type, $statsFileIn, $edFile, $treeFileOut ) = @_;
   my ( @lines, $i, %nstate );

   $nstate{'cmp'} = $nState;
   $nstate{'dur'} = 1;

   open( QSFILE, "$qs{$type}" ) || die "Cannot open file: $!";
   @lines = <QSFILE>;
   close(QSFILE);

   open( EDFILE, ">$edFile" ) || die "Cannot open file: $!";
   print EDFILE "// load stats file\n";
   print EDFILE "RO $gam{$type} \"$statsFileIn\"\n\n";
   print EDFILE "TR 0\n\n";
   print EDFILE "// questions for decision tree-based context clustering\n";
   print EDFILE @lines;
   print EDFILE "TR 3\n\n";
   print EDFILE "// construct decision trees\n";

   for ( $i = 2 ; $i <= $nstate{ $t2s{$type} } + 1 ; $i++ ) {
      print EDFILE "TB $thr{$type} ${type}_s${i}_ {*.state[${i}].stream[$strb{$type}-$stre{$type}]}\n";
   }
   print EDFILE "\nTR 1\n\n";
   print EDFILE "// output constructed trees\n";
   print EDFILE "ST \"$treeFileOut\"\n";
   close(EDFILE);
}

# sub routine for generating .hed files for decision-tree clustering of GV
sub make_edfile_state_gv {
   my ( $type, $statsFileIn, $edFile, $treeFileOut ) = @_;
   my ( @lines, $typeTemp, $streamIndex );

   $streamIndex = 1;
   foreach $typeTemp (@cmp) {
      if ( $typeTemp eq $type ) {
         last;
      }
      $streamIndex++;
   }

   open( QSFILE, "$qs_utt{$type}" ) || die "Cannot open file: $!";
   @lines = <QSFILE>;
   close(QSFILE);

   open( EDFILE, ">$edFile" ) || die "Cannot open file: $!";
   print EDFILE "// load stats file\n";
   print EDFILE "RO $gvgam{$type} \"$statsFileIn\"\n";
   print EDFILE "TR 0\n\n";
   print EDFILE "// questions for decision tree-based context clustering\n";
   print EDFILE @lines;
   print EDFILE "TR 3\n\n";
   print EDFILE "// construct decision trees\n";
   print EDFILE "TB $gvthr{$type} gv_${type}_ {*.state[2].stream[$streamIndex]}\n";
   print EDFILE "\nTR 1\n\n";
   print EDFILE "// output constructed trees\n";
   print EDFILE "ST \"$treeFileOut\"\n";
   close(EDFILE);
}

# sub routine for untying structures
sub make_edfile_untie {
   my ( $set, $edFile ) = @_;
   my ( $type, $i, %nstate );

   $nstate{'cmp'} = $nState;
   $nstate{'dur'} = 1;

   open( EDFILE, ">$edFile" ) || die "Cannot open file: $!";

   print EDFILE "// untie parameter sharing structure\n";
   foreach $type ( @{ $ref{$set} } ) {
      for ( $i = 2 ; $i <= $nstate{$set} + 1 ; $i++ ) {
         if ( $#{ $ref{$set} } eq 0 ) {
            print EDFILE "UT {*.state[$i]}\n";
         }
         else {
            print EDFILE "UT {*.state[$i].stream[$strb{$type}-$stre{$type}]}\n";
         }
      }
   }

   close(EDFILE);
}

# sub routine to increase the number of mixture components
sub make_edfile_upmix {
   my ( $set, $edFile ) = @_;
   my ( $type, $i, %nstate );

   $nstate{'cmp'} = $nState;
   $nstate{'dur'} = 1;

   open( EDFILE, ">$edFile" ) || die "Cannot open file: $!";

   print EDFILE "// increase the number of mixtures per stream\n";
   foreach $type ( @{ $ref{$set} } ) {
      for ( $i = 2 ; $i <= $nstate{$set} + 1 ; $i++ ) {
         if ( $#{ $ref{$set} } eq 0 ) {
            print EDFILE "MU +1 {*.state[$i].mix}\n";
         }
         else {
            print EDFILE "MU +1 {*.state[$i].stream[$strb{$type}-$stre{$type}].mix}\n";
         }
      }
   }

   close(EDFILE);
}

# sub routine to convert statistics file for cmp into one for dur
sub convstats {
   my ( $cmpStatsFileIn, $durStatsFileOut ) = @_;
   my (@LINE);

   open( IN,  "$cmpStatsFileIn" )  || die "Cannot open file: $!";
   open( OUT, ">$durStatsFileOut" ) || die "Cannot open file: $!";
   while (<IN>) {
      @LINE = split(' ');
      printf OUT ( "%4d %14s %4d %4d\n", $LINE[0], $LINE[1], $LINE[2], $LINE[2] );
   }
   close(IN);
   close(OUT);
}

# sub routine for generating low pass filter of hts_engine API
sub make_lpf {
   my ($dirOut) = @_;
   my ( $lfil, @coef, $coefSize, $i, $j );

   $lfil     = `$PERL $datdir/scripts/makefilter.pl $sr 0`;
   @coef     = split( '\s', $lfil );
   $coefSize = @coef;

   shell("rm -f $dirOut/lpf.pdf");
   shell("touch $dirOut/lpf.pdf");
   for ( $i = 0 ; $i < $nState ; $i++ ) {
      shell("echo 1 | $X2X +ai >> $dirOut/lpf.pdf");
   }
   for ( $i = 0 ; $i < $nState ; $i++ ) {
      for ( $j = 0 ; $j < $coefSize ; $j++ ) {
         shell("echo $coef[$j] | $X2X +af >> $dirOut/lpf.pdf");
      }
      for ( $j = 0 ; $j < $coefSize ; $j++ ) {
         shell("echo 0.0 | $X2X +af >> $dirOut/lpf.pdf");
      }
   }

   open( INF, "> $dirOut/tree-lpf.inf" );
   for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {
      print INF "{*}[${i}]\n";
      print INF "   \"lpf_s${i}_1\"\n";
   }
   close(INF);

   open( WIN, "> $dirOut/lpf.win1" );
   print WIN "1 1.0\n";
   close(WIN);
}

# sub routine for generating HTS voice for hts_engine API
sub make_hts_voice {
   my ( $dirIn, $useGv, $useCdGv, $htsVoiceFileOut ) = @_;
   my ( $i, $type, $tmp, @coef, $coefSize, $file_index, $s, $e, $file_size, @STAT );

   open( HTSVOICE, "> $htsVoiceFileOut" );

   # global information
   print HTSVOICE "[GLOBAL]\n";
   print HTSVOICE "HTS_VOICE_VERSION:1.0\n";
   print HTSVOICE "SAMPLING_FREQUENCY:${sr}\n";
   print HTSVOICE "FRAME_PERIOD:${fs}\n";
   print HTSVOICE "NUM_STATES:${nState}\n";
   print HTSVOICE "NUM_STREAMS:" . ( ${ nPdfStreams { 'cmp' } } + 1 ) . "\n";
   print HTSVOICE "STREAM_TYPE:";

   for ( $i = 0 ; $i < @cmp ; $i++ ) {
      if ( $i != 0 ) {
         print HTSVOICE ",";
      }
      $tmp = get_hts_voice_stream_name( $cmp[$i] );
      print HTSVOICE "${tmp}";
   }
   print HTSVOICE ",LPF\n";
   print HTSVOICE "FULLCONTEXT_FORMAT:${fclf}\n";
   print HTSVOICE "FULLCONTEXT_VERSION:${fclv}\n";
   if ($nosilgv) {
      print HTSVOICE "GV_OFF_CONTEXT:";
      for ( $i = 0 ; $i < @slnt ; $i++ ) {
         if ( $i != 0 ) {
            print HTSVOICE ",";
         }
         print HTSVOICE "\"*-${slnt[$i]}+*\"";
      }
   }
   print HTSVOICE "\n";
   print HTSVOICE "COMMENT:\n";

   # stream information
   print HTSVOICE "[STREAM]\n";
   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      print HTSVOICE "VECTOR_LENGTH[${tmp}]:${ordr{$type}}\n";
   }
   $type     = "lpf";
   $tmp      = get_hts_voice_stream_name($type);
   @coef     = split( '\s', `$PERL $datdir/scripts/makefilter.pl $sr 0` );
   $coefSize = @coef;
   print HTSVOICE "VECTOR_LENGTH[${tmp}]:${coefSize}\n";
   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      print HTSVOICE "IS_MSD[${tmp}]:${msdi{$type}}\n";
   }
   $type = "lpf";
   $tmp  = get_hts_voice_stream_name($type);
   print HTSVOICE "IS_MSD[${tmp}]:0\n";
   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      print HTSVOICE "NUM_WINDOWS[${tmp}]:${nwin{$type}}\n";
   }
   $type = "lpf";
   $tmp  = get_hts_voice_stream_name($type);
   print HTSVOICE "NUM_WINDOWS[${tmp}]:1\n";
   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      if ($useGv) {
         print HTSVOICE "USE_GV[${tmp}]:1\n";
      }
      else {
         print HTSVOICE "USE_GV[${tmp}]:0\n";
      }
   }
   $type = "lpf";
   $tmp  = get_hts_voice_stream_name($type);
   print HTSVOICE "USE_GV[${tmp}]:0\n";
   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      if ( $tmp eq "MCP" ) {
         print HTSVOICE "OPTION[${tmp}]:ALPHA=$fw\n";
      }
      elsif ( $tmp eq "LSP" ) {
         print HTSVOICE "OPTION[${tmp}]:ALPHA=$fw,GAMMA=$gm,LN_GAIN=$lg\n";
      }
      else {
         print HTSVOICE "OPTION[${tmp}]:\n";
      }
   }
   $type = "lpf";
   $tmp  = get_hts_voice_stream_name($type);
   print HTSVOICE "OPTION[${tmp}]:\n";

   # position
   $file_index = 0;
   print HTSVOICE "[POSITION]\n";
   $file_size = get_file_size("$dirIn/dur.pdf");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "DURATION_PDF:${s}-${e}\n";
   $file_index += $file_size;
   $file_size = get_file_size("$dirIn/tree-dur.inf");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "DURATION_TREE:${s}-${e}\n";
   $file_index += $file_size;

   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      print HTSVOICE "STREAM_WIN[${tmp}]:";
      for ( $i = 0 ; $i < $nwin{$type} ; $i++ ) {
         $file_size = get_file_size("$dirIn/$win{$type}[$i]");
         $s         = $file_index;
         $e         = $file_index + $file_size - 1;
         if ( $i != 0 ) {
            print HTSVOICE ",";
         }
         print HTSVOICE "${s}-${e}";
         $file_index += $file_size;
      }
      print HTSVOICE "\n";
   }
   $type = "lpf";
   $tmp  = get_hts_voice_stream_name($type);
   print HTSVOICE "STREAM_WIN[${tmp}]:";
   $file_size = get_file_size("$dirIn/$win{$type}[0]");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "${s}-${e}";
   $file_index += $file_size;
   print HTSVOICE "\n";

   foreach $type (@cmp) {
      $tmp       = get_hts_voice_stream_name($type);
      $file_size = get_file_size("$dirIn/${type}.pdf");
      $s         = $file_index;
      $e         = $file_index + $file_size - 1;
      print HTSVOICE "STREAM_PDF[$tmp]:${s}-${e}\n";
      $file_index += $file_size;
   }
   $type      = "lpf";
   $tmp       = get_hts_voice_stream_name($type);
   $file_size = get_file_size("$dirIn/${type}.pdf");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "STREAM_PDF[$tmp]:${s}-${e}\n";
   $file_index += $file_size;

   foreach $type (@cmp) {
      $tmp       = get_hts_voice_stream_name($type);
      $file_size = get_file_size("$dirIn/tree-${type}.inf");
      $s         = $file_index;
      $e         = $file_index + $file_size - 1;
      print HTSVOICE "STREAM_TREE[$tmp]:${s}-${e}\n";
      $file_index += $file_size;
   }
   $type      = "lpf";
   $tmp       = get_hts_voice_stream_name($type);
   $file_size = get_file_size("$dirIn/tree-${type}.inf");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "STREAM_TREE[$tmp]:${s}-${e}\n";
   $file_index += $file_size;

   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      if ($useGv) {
         $file_size = get_file_size("$dirIn/gv-${type}.pdf");
         $s         = $file_index;
         $e         = $file_index + $file_size - 1;
         print HTSVOICE "GV_PDF[$tmp]:${s}-${e}\n";
         $file_index += $file_size;
      }
   }
   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      if ( $useGv && $useCdGv ) {
         $file_size = get_file_size("$dirIn/tree-gv-${type}.inf");
         $s         = $file_index;
         $e         = $file_index + $file_size - 1;
         print HTSVOICE "GV_TREE[$tmp]:${s}-${e}\n";
         $file_index += $file_size;
      }
   }

   # data information
   print HTSVOICE "[DATA]\n";
   open( I, "$dirIn/dur.pdf" ) || die "Cannot open file: $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;
   open( I, "$dirIn/tree-dur.inf" ) || die "Cannot open file: $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;

   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      for ( $i = 0 ; $i < $nwin{$type} ; $i++ ) {
         open( I, "$dirIn/$win{$type}[$i]" ) || die "Cannot open file: $!";
         @STAT = stat(I);
         read( I, $DATA, $STAT[7] );
         close(I);
         print HTSVOICE $DATA;
      }
   }
   $type = "lpf";
   $tmp  = get_hts_voice_stream_name($type);
   open( I, "$dirIn/$win{$type}[0]" ) || die "Cannot open file: $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;

   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      open( I, "$dirIn/${type}.pdf" ) || die "Cannot open file: $!";
      @STAT = stat(I);
      read( I, $DATA, $STAT[7] );
      close(I);
      print HTSVOICE $DATA;
   }
   $type = "lpf";
   $tmp  = get_hts_voice_stream_name($type);
   open( I, "$dirIn/${type}.pdf" ) || die "Cannot open file: $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;

   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      open( I, "$dirIn/tree-${type}.inf" ) || die "Cannot open file: $!";
      @STAT = stat(I);
      read( I, $DATA, $STAT[7] );
      close(I);
      print HTSVOICE $DATA;
   }
   $type = "lpf";
   $tmp  = get_hts_voice_stream_name($type);
   open( I, "$dirIn/tree-${type}.inf" ) || die "Cannot open file: $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;

   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      if ($useGv) {
         open( I, "$dirIn/gv-${type}.pdf" ) || die "Cannot open file: $!";
         @STAT = stat(I);
         read( I, $DATA, $STAT[7] );
         close(I);
         print HTSVOICE $DATA;
      }
   }
   foreach $type (@cmp) {
      $tmp = get_hts_voice_stream_name($type);
      if ( $useGv && $useCdGv ) {
         open( I, "$dirIn/tree-gv-${type}.inf" ) || die "Cannot open file: $!";
         @STAT = stat(I);
         read( I, $DATA, $STAT[7] );
         close(I);
         print HTSVOICE $DATA;
      }
   }
   close(HTSVOICE);
}

# sub routine for getting stream name for HTS voice
sub get_hts_voice_stream_name {
   my ($from) = @_;
   my ($to);

   if ( $from eq 'mgc' ) {
      if ( $gm == 0 ) {
         $to = "MCP";
      }
      else {
         $to = "LSP";
      }
   }
   else {
      $to = uc $from;
   }

   return $to;
}

# sub routine for getting file size
sub get_file_size {
   my ($file) = @_;
   my ($file_size);

   $file_size = `$WC -c < $file`;
   chomp($file_size);

   return $file_size;
}

# Applies mel-cepstral postfiltering to speech parameter files.
sub apply_postfiltering_mcep {
   my ( $genDirIn, $uttIdsFile, $typeGood, $genDirOut ) = @_;
   my ( $i, $line, $uttId, $type );

   make_path $genDirOut;

   foreach $type (@cmp) {
      if ( $type eq $typeGood ) {
         # output postfiltering weight coefficient
         $line = "echo 1 1 ";
         for ( $i = 2 ; $i < $ordr{$type} ; $i++ ) {
            $line .= "$pf_mcp ";
         }
         $line .= "| $X2X +af > $genDirOut/_weight_$type";
         shell($line);
      }
   }

   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      foreach $type (@cmp) {
         if ( $type eq $typeGood ) {
            # calculate auto-correlation of original mcep
            $line = "$FREQT -m " . ( $ordr{$type} - 1 ) . " -a $fw -M $co -A 0 < $genDirIn/$uttId.$type | ";
            $line .= "$C2ACR -m $co -M 0 -l $fl > $genDirOut/$uttId.$type.r0";
            shell($line);

            # calculate auto-correlation of postfiltered mcep
            $line = "$VOPR -m -n " . ( $ordr{$type} - 1 ) . " < $genDirIn/$uttId.$type $genDirOut/_weight_$type | ";
            $line .= "$FREQT -m " . ( $ordr{$type} - 1 ) . " -a $fw -M $co -A 0 | ";
            $line .= "$C2ACR -m $co -M 0 -l $fl > $genDirOut/$uttId.$type.p_r0";
            shell($line);

            # calculate MLSA coefficients from postfiltered mcep
            $line = "$VOPR -m -n " . ( $ordr{$type} - 1 ) . " < $genDirIn/$uttId.$type $genDirOut/_weight_$type | ";
            $line .= "$MC2B -m " . ( $ordr{$type} - 1 ) . " -a $fw | ";
            $line .= "$BCP -n " .  ( $ordr{$type} - 1 ) . " -s 0 -e 0 > $genDirOut/$uttId.$type.b0";
            shell($line);

            # calculate 0.5 * log(acr_orig/acr_post)) and add it to 0th MLSA coefficient
            $line = "$VOPR -d < $genDirOut/$uttId.$type.r0 $genDirOut/$uttId.$type.p_r0 | ";
            $line .= "$SOPR -LN -d 2 | ";
            $line .= "$VOPR -a $genDirOut/$uttId.$type.b0 > $genDirOut/$uttId.$type.p_b0";
            shell($line);

            # generate postfiltered mcep
            $line = "$VOPR -m -n " . ( $ordr{$type} - 1 ) . " < $genDirIn/$uttId.$type $genDirOut/_weight_$type | ";
            $line .= "$MC2B -m " .  ( $ordr{$type} - 1 ) . " -a $fw | ";
            $line .= "$BCP -n " .   ( $ordr{$type} - 1 ) . " -s 1 -e " . ( $ordr{$type} - 1 ) . " | ";
            $line .= "$MERGE -n " . ( $ordr{$type} - 2 ) . " -s 0 -N 0 $genDirOut/$uttId.$type.p_b0 | ";
            $line .= "$B2MC -m " .  ( $ordr{$type} - 1 ) . " -a $fw > $genDirOut/$uttId.$type";
            shell($line);

            $line = "rm -f $genDirOut/$uttId.$type.r0 $genDirOut/$uttId.$type.p_r0 $genDirOut/$uttId.$type.b0 $genDirOut/$uttId.$type.p_b0";
            shell($line);
         }
         else {
            shell("cp $genDirIn/$uttId.$type $genDirOut/");
         }
      }
   }
   close(UTTIDS);
}

# Converts speech parameter files using LSPs to ones using mel-cepstra.
sub convert_lsp_to_mcep {
   my ( $genDirIn, $uttIdsFile, $typeGood, $genDirOut ) = @_;
   my ( $lgopt, $uttId, $type, $line );

   make_path $genDirOut;

   if ($lg) {
      $lgopt = "-L";
   }
   else {
      $lgopt = "";
   }

   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      foreach $type (@cmp) {
         if ( $type eq $typeGood ) {
            # MGC-LSPs -> MGC coefficients
            $line = "$LSPCHECK -m " . ( $ordr{$type} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 $genDirIn/$uttId.$type | ";
            $line .= "$LSP2LPC -m " . ( $ordr{$type} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt | ";
            $line .= "$MGC2MGC -m " . ( $ordr{$type} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $ordr{$type} - 1 ) . " -A $fw -C $gm " . " > $genDirOut/$uttId.$type";
            shell($line);
         }
         else {
            shell("cp $genDirIn/$uttId.$type $genDirOut/");
         }
      }
   }
   close(UTTIDS);
}

# Applies LSP-based postfiltering to speech parameter files.
sub apply_postfiltering_lsp {
   my ( $genDirIn, $uttIdsFile, $typeGood, $genDirOut ) = @_;
   my ( $lgopt, $uttId, $type, $line, $i, @lsp, $d_1, $d_2, $plsp, $data );

   make_path $genDirOut;

   if ($lg) {
      $lgopt = "-L";
   }
   else {
      $lgopt = "";
   }

   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      foreach $type (@cmp) {
         if ( $type eq $typeGood ) {
            $line = "$LSPCHECK -m " . ( $ordr{$type} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 $genDirIn/$uttId.$type | ";
            $line .= "$LSP2LPC -m " . ( $ordr{$type} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt | ";
            $line .= "$MGC2MGC -m " . ( $ordr{$type} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $fl - 1 ) . " -A 0.0 -G 1.0 | ";
            $line .= "$SOPR -P | $VSUM -t $fl | $SOPR -LN -m 0.5 > $genDirOut/$uttId.$type.ene1";
            shell($line);

            # postfiltering
            open( LSP,  "$X2X +fa < $genDirIn/$uttId.$type |" );
            open( GAIN, ">$genDirOut/$uttId.$type.gain" );
            open( PLSP, ">$genDirOut/$uttId.$type.lsp" );
            while (1) {
               @lsp = ();
               for ( $i = 0 ; $i < $ordr{$type} && ( $line = <LSP> ) ; $i++ ) {
                  push( @lsp, $line );
               }
               if ( $ordr{$type} != @lsp ) { last; }

               $data = pack( "f", $lsp[0] );
               print GAIN $data;
               for ( $i = 1 ; $i < $ordr{$type} ; $i++ ) {
                  if ( $i > 1 && $i < $ordr{$type} - 1 ) {
                     $d_1 = $pf_lsp * ( $lsp[ $i + 1 ] - $lsp[$i] );
                     $d_2 = $pf_lsp * ( $lsp[$i] - $lsp[ $i - 1 ] );
                     $plsp = $lsp[ $i - 1 ] + $d_2 + ( $d_2 * $d_2 * ( ( $lsp[ $i + 1 ] - $lsp[ $i - 1 ] ) - ( $d_1 + $d_2 ) ) ) / ( ( $d_2 * $d_2 ) + ( $d_1 * $d_1 ) );
                  }
                  else {
                     $plsp = $lsp[$i];
                  }
                  $data = pack( "f", $plsp );
                  print PLSP $data;
               }
            }
            close(PLSP);
            close(GAIN);
            close(LSP);

            $line = "$MERGE -s 1 -l 1 -L " . ( $ordr{$type} - 1 ) . " -N " . ( $ordr{$type} - 2 ) . " $genDirOut/$uttId.$type.lsp < $genDirOut/$uttId.$type.gain | ";
            $line .= "$LSPCHECK -m " . ( $ordr{$type} - 1 ) . " -s " .                     ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 | ";
            $line .= "$LSP2LPC -m " .  ( $ordr{$type} - 1 ) . " -s " .                     ( $sr / 1000 ) . " $lgopt | ";
            $line .= "$MGC2MGC -m " .  ( $ordr{$type} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $fl - 1 ) . " -A 0.0 -G 1.0 | ";
            $line .= "$SOPR -P | $VSUM -t $fl | $SOPR -LN -m 0.5 > $genDirOut/$uttId.$type.ene2 ";
            shell($line);

            $line = "$VOPR -l 1 -d $genDirOut/$uttId.$type.ene2 $genDirOut/$uttId.$type.ene2 | $SOPR -LN -m 0.5 | ";
            $line .= "$VOPR -a $genDirOut/$uttId.$type.gain | ";
            $line .= "$MERGE -s 1 -l 1 -L " . ( $ordr{$type} - 1 ) . " -N " . ( $ordr{$type} - 2 ) . " $genDirOut/$uttId.$type.lsp > $genDirOut/$uttId.$type";
            shell($line);

            $line = "rm -f $genDirOut/$uttId.$type.ene1 $genDirOut/$uttId.$type.ene2 $genDirOut/$uttId.$type.gain $genDirOut/$uttId.$type.lsp";
            shell($line);
         }
         else {
            shell("cp $genDirIn/$uttId.$type $genDirOut/");
         }
      }
   }
   close(UTTIDS);
}

# Synthesizes raw float waveforms using SPTK-based vocoder.
#
# N.B. synthDirOut can be equal to genDirIn.
sub synth_raw_float_sptk {
   my ( $genDirIn, $uttIdsFile, $synthDirOut ) = @_;
   my ( $uttId, $line, $lfil, $hfil );

   make_path $synthDirOut;

   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      print " Synthesizing a speech waveform from $uttId.mgc and $uttId.lf0...";

      # convert log F0 to pitch
      $line = "$SOPR -magic -1.0E+10 -EXP -INV -m $sr -MAGIC 0.0 $genDirIn/$uttId.lf0 > $synthDirOut/$uttId.pit";
      shell($line);

      # synthesize waveform
      $lfil = `$PERL $datdir/scripts/makefilter.pl $sr 0`;
      $hfil = `$PERL $datdir/scripts/makefilter.pl $sr 1`;

      $line = "$SOPR -m 0 $synthDirOut/$uttId.pit | $EXCITE -n -p $fs | $DFS -b $hfil > $synthDirOut/$uttId.unv";
      shell($line);

      $line = "$EXCITE -n -p $fs $synthDirOut/$uttId.pit | ";
      $line .= "$DFS -b $lfil | $VOPR -a $synthDirOut/$uttId.unv | ";
      $line .= "$MGLSADF -P 5 -m " . ( $ordr{'mgc'} - 1 ) . " -p $fs -a $fw -c $gm $genDirIn/$uttId.mgc > $synthDirOut/$uttId.x32768.0.raw";
      shell($line);

      $line = "rm -f $synthDirOut/$uttId.pit $synthDirOut/$uttId.unv";
      shell($line);

      print "done\n";
   }
   close(UTTIDS);
}

# Synthesizes raw float waveforms using STRAIGHT-based vocoder.
#
# N.B. synthDirOut can be equal to genDirIn.
sub synth_raw_float_straight {
   my ( $genDirIn, $uttIdsFile, $synthDirOut ) = @_;
   my ( $uttId, $line );

   make_path $synthDirOut;

   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      print " Synthesizing a speech waveform from $uttId.mgc, $uttId.lf0, and $uttId.bap... ";

      # convert log F0 to F0
      $line = "$SOPR -magic -1.0E+10 -EXP -MAGIC 0.0 $genDirIn/$uttId.lf0 > $synthDirOut/$uttId.f0 ";
      shell($line);

      # convert mel-cepstral coefficients to spectrum
      if ( $gm == 0 ) {
         shell( "$MGC2SP -a $fw -g $gm -m " . ( $ordr{'mgc'} - 1 ) . " -l 2048 -o 2 $genDirIn/$uttId.mgc > $synthDirOut/$uttId.sp" );
      }
      else {
         shell( "$MGC2SP -a $fw -c $gm -m " . ( $ordr{'mgc'} - 1 ) . " -l 2048 -o 2 $genDirIn/$uttId.mgc > $synthDirOut/$uttId.sp" );
      }

      # convert band-aperiodicity to aperiodicity
      shell( "$MGC2SP -a $fw -g 0 -m " . ( $ordr{'bap'} - 1 ) . " -l 2048 -o 0 $genDirIn/$uttId.bap > $synthDirOut/$uttId.ap" );

      # synthesize raw float waveform
      open( SYN, ">$synthDirOut/$uttId.m" ) || die "Cannot open file: $!";
      printf SYN "path(path, '$STRAIGHT');\n";
      printf SYN "prm.spectralUpdateInterval = %f;\n", 1000.0 * $fs / $sr;
      printf SYN "prm.levelNormalizationIndicator = 0;\n";
      printf SYN "\n";
      printf SYN "fprintf(1, '\\nSynthesizing for utterance $uttId\\n');\n";
      printf SYN "f0_fid = fopen('$synthDirOut/$uttId.f0', 'r');\n";
      printf SYN "sp_fid = fopen('$synthDirOut/$uttId.sp', 'r');\n";
      printf SYN "ap_fid = fopen('$synthDirOut/$uttId.ap', 'r');\n";
      printf SYN "f0 = fread(f0_fid, Inf, 'float');\n";
      printf SYN "sp = fread(sp_fid, Inf, 'float');\n";
      printf SYN "ap = fread(ap_fid, Inf, 'float');\n";
      printf SYN "fclose(f0_fid);\n";
      printf SYN "fclose(sp_fid);\n";
      printf SYN "fclose(ap_fid);\n";
      printf SYN "T = size(f0, 1);\n";
      printf SYN "f0 = reshape(f0, [1, T]);\n";
      printf SYN "sp = reshape(sp, [1025, T]);\n";
      printf SYN "ap = reshape(ap, [1025, T]);\n";
      printf SYN "[audio] = exstraightsynth(f0, sp, ap, $sr, prm);\n";
      printf SYN "audio_fid = fopen('$synthDirOut/$uttId.x32768.0.raw', 'w');\n";
      printf SYN "audio = fwrite(audio_fid, audio, 'float');\n";
      printf SYN "fclose(audio_fid);\n";
      printf SYN "\n";
      printf SYN "quit;\n";
      close(SYN);
      shell("$MATLAB < $synthDirOut/$uttId.m");

      $line = "rm -f $synthDirOut/$uttId.m $synthDirOut/$uttId.sp $synthDirOut/$uttId.ap $synthDirOut/$uttId.f0";
      shell($line);

      print "done\n";
   }
   close(UTTIDS);
}

# Converts raw float waveform files to RIFF wav files.
#
# N.B. synthDirOut can be equal to synthDirIn.
sub raw_float_to_wav {
   my ( $synthDirIn, $uttIdsFile, $synthDirOut ) = @_;
   my ( $uttId, $line );

   make_path $synthDirOut;

   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      $line = "cat $synthDirIn/$uttId.x32768.0.raw | $X2X +fs -r -o > $synthDirOut/$uttId.raw";
      shell($line);

      $line = "$RAW2WAV -s " . ( $sr / 1000 ) . " -d $synthDirOut $synthDirOut/$uttId.raw";
      shell($line);

      $line = "rm -f $synthDirOut/$uttId.raw";
      shell($line);
   }
   close(UTTIDS);
}

# Synthesizes waveforms from speech parameter files with optional postfiltering.
#
# N.B. synthDirOut can be equal to genDirIn.
sub synth_wave {
   my ( $genDirIn, $uttIdsFile, $useMSPF, $mspfStatsDir, $synthDirOut ) = @_;
   my ( $genDirPf, $genDirStd );

   make_path $synthDirOut;

   # apply postfiltering
   $genDirPf = "$synthDirOut/_postfiltered";
   if ($useMSPF) {
      print "Applying modulation spectrum-based postfiltering\n";
      apply_postfiltering_mspf( $genDirIn, $uttIdsFile, $mspfStatsDir, "mgc", $genDirPf );
   }
   elsif ( !$useGV && $gm == 0 && $pf_mcp != 1.0 ) {
      print "Applying mcep-based postfiltering\n";
      apply_postfiltering_mcep( $genDirIn, $uttIdsFile, "mgc", $genDirPf );
   }
   elsif ( !$useGV && $gm != 0 && $pf_lsp != 1.0 ) {
      print "Applying LSP-based postfiltering\n";
      apply_postfiltering_lsp( $genDirIn, $uttIdsFile, "mgc", $genDirPf );
   }
   else {
      $genDirPf = $genDirIn;
   }

   # convert speech parameters to standard mel cepstral-based form
   $genDirStd = "$synthDirOut/_mcep";
   if ( $gm == 0 ) {
      $genDirStd = $genDirPf;
   }
   else {
      print "Converting LSP to mcep\n";
      convert_lsp_to_mcep( $genDirPf, $uttIdsFile, "mgc", $genDirStd );
   }

   # synthesize raw float waveforms
   if ( !$usestraight ) {
      print "Synthesizing using SPTK-based vocoder\n";
      synth_raw_float_sptk( $genDirStd, $uttIdsFile, $synthDirOut );
   }
   else {
      print "Synthesizing using STRAIGHT-based vocoder\n";
      synth_raw_float_straight( $genDirStd, $uttIdsFile, $synthDirOut );
   }

   # convert raw float waveforms to wav files
   raw_float_to_wav( $synthDirOut, $uttIdsFile, $synthDirOut );
}

# Applies modulation spectrum-based postfiltering to speech parameter files.
sub apply_postfiltering_mspf {
   my ( $genDirIn, $uttIdsFile, $statsDir, $typeGood, $genDirOut ) = @_;
   my ( $uttId, $type, $T, $line, $d, @seq );

   make_path $genDirOut;

   open( UTTIDS, $uttIdsFile ) || die "Cannot open file: $!";
   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      foreach $type (@cmp) {
         if ( $type eq $typeGood ) {
            $T = get_file_size("$genDirIn/$uttId.$type") / $ordr{$type} / 4;

            # subtract utterance-level mean
            $line = get_cmd_utmean( "$genDirIn/$uttId.$type", $type );
            shell("$line > $genDirOut/$uttId.$type.mean");
            $line = get_cmd_vopr( "$genDirIn/$uttId.$type", "-s", "$genDirOut/$uttId.$type.mean", $type );
            shell("$line > $genDirOut/$uttId.$type.subtracted");

            for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {
               # calculate modulation spectrum/phase
               $line = get_cmd_seq2ms( "$genDirOut/$uttId.$type.subtracted", $type, $d );
               shell("$line > $genDirOut/$uttId.$type.mspec_dim$d");
               $line = get_cmd_seq2mp( "$genDirOut/$uttId.$type.subtracted", $type, $d );
               shell("$line > $genDirOut/$uttId.$type.mphase_dim$d");

               # convert
               $line = "cat $genDirOut/$uttId.$type.mspec_dim$d | ";
               $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -s $statsDir/gen/${type}_dim$d.mean | ";
               $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -d $statsDir/gen/${type}_dim$d.stdd | ";
               $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -m $statsDir/nat/${type}_dim$d.stdd | ";
               $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -a $statsDir/nat/${type}_dim$d.mean | ";

               # apply weight
               $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -s $genDirOut/$uttId.$type.mspec_dim$d | ";
               $line .= "$SOPR -m $mspfe{$type} | ";
               $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -a $genDirOut/$uttId.$type.mspec_dim$d > $genDirOut/$uttId.$type.p_mspec_dim$d";
               shell($line);

               # calculate filtered sequence
               push( @seq, msmp2seq( "$genDirOut/$uttId.$type.p_mspec_dim$d", "$genDirOut/$uttId.$type.mphase_dim$d", $T ) );
            }
            open( SEQ, ">$genDirOut/$uttId.$type.tmp" ) || die "Cannot open file: $!";
            print SEQ join( "\n", @seq );
            close(SEQ);
            shell("$X2X +af $genDirOut/$uttId.$type.tmp | $TRANSPOSE -m $ordr{$type} -n $T > $genDirOut/$uttId.$type.p_subtracted");

            # add utterance-level mean
            $line = get_cmd_vopr( "$genDirOut/$uttId.$type.p_subtracted", "-a", "$genDirOut/$uttId.$type.mean", $type );
            shell("$line > $genDirOut/$uttId.$type");

            shell("rm -f $genDirOut/$uttId.$type.mspec_dim* $genDirOut/$uttId.$type.mphase_dim* $genDirOut/$uttId.$type.p_mspec_dim*");
            shell("rm -f $genDirOut/$uttId.$type.subtracted $genDirOut/$uttId.$type.p_subtracted $genDirOut/$uttId.$type.mean $genDirOut/$uttId.$type.tmp");
         }
         else {
            shell("cp $genDirIn/$uttId.$type $genDirOut/");
         }
      }
   }
   close(UTTIDS);
}

# sub routine for calculating temporal sequence from modulation spectrum/phase
sub msmp2seq {
   my ( $file_ms, $file_mp, $T ) = @_;
   my ( @msp, @seq, @wseq, @ms, @mp, $d, $pos, $bias, $mspfShift );

   @ms = split( /\n/, `$SOPR -EXP  $file_ms | $X2X +fa` );
   @mp = split( /\n/, `$SOPR -m pi $file_mp | $X2X +fa` );
   $mspfShift = ( $mspfLength - 1 ) / 2;

   # ifft (modulation spectrum & modulation phase -> temporal sequence)
   for ( $pos = 0, $bias = 0 ; $pos <= $#ms ; $pos += $mspfFFTLen / 2 + 1 ) {
      for ( $d = 0 ; $d <= $mspfFFTLen / 2 ; $d++ ) {
         $msp[ $d + $bias ] = $ms[ $d + $pos ] * cos( $mp[ $d + $pos ] );
         $msp[ $d + $mspfFFTLen + $bias ] = $ms[ $d + $pos ] * sin( $mp[ $d + $pos ] );
         if ( $d != 0 && $d != $mspfFFTLen / 2 ) {
            $msp[ $mspfFFTLen - $d + $bias ] = $msp[ $d + $bias ];
            $msp[ 2 * $mspfFFTLen - $d + $bias ] = -$msp[ $d + $mspfFFTLen + $bias ];
         }
      }
      $bias += 2 * $mspfFFTLen;
   }
   open( MSP, ">$file_ms.tmp" ) || die "Cannot open file: $!";
   print MSP join( "\n", @msp );
   close(MSP);
   @wseq = split( "\n", `$X2X +af $file_ms.tmp | $IFFTR -l $mspfFFTLen | $X2X +fa` );
   shell("rm -f $file_ms.tmp");

   # overlap-addition
   for ( $pos = 0, $bias = 0 ; $pos <= $#wseq ; $pos += $mspfFFTLen ) {
      for ( $d = 0 ; $d < $mspfFFTLen ; $d++ ) {
         $seq[ $d + $bias ] += $wseq[ $d + $pos ];
      }
      $bias += $mspfShift;
   }

   return @seq[ $mspfShift .. ( $T + $mspfShift - 1 ) ];
}

# sub routine for shell command to get utterance mean
sub get_cmd_utmean {
   my ( $file, $type ) = @_;

   return "$VSTAT -l $ordr{$type} -o 1 < $file ";
}

# sub routine for shell command to subtract vector from sequence
sub get_cmd_vopr {
   my ( $file, $opt, $vec, $type ) = @_;
   my ( $value, $line );

   if ( $ordr{$type} == 1 ) {
      $value = `$X2X +fa < $vec`;
      chomp($value);
      $line = "$SOPR $opt $value < $file ";
   }
   else {
      $line = "$VOPR -l $ordr{$type} $opt $vec < $file ";
   }
   return $line;
}

# sub routine for shell command to calculate modulation spectrum from sequence
sub get_cmd_seq2ms {
   my ( $file, $type, $d ) = @_;
   my ( $T, $line, $mspfShift );

   $T         = get_file_size("$file") / $ordr{$type} / 4;
   $mspfShift = ( $mspfLength - 1 ) / 2;

   $line = "$BCP -l $ordr{$type} -L 1 -s $d -e $d < $file | ";
   $line .= "$WINDOW -l $T -L " . ( $T + $mspfShift ) . " -n 0 -w 5 | ";
   $line .= "$FRAME -l $mspfLength -p $mspfShift | ";
   $line .= "$WINDOW -l $mspfLength -L $mspfFFTLen -n 0 -w 3 | ";
   $line .= "$SPEC -l $mspfFFTLen -o 1 -e 1e-30 ";

   return $line;
}

# sub routine for shell command to calculate modulation phase from sequence
sub get_cmd_seq2mp {
   my ( $file, $type, $d ) = @_;
   my ( $T, $line, $mspfShift );

   $T         = get_file_size("$file") / $ordr{$type} / 4;
   $mspfShift = ( $mspfLength - 1 ) / 2;

   $line = "$BCP -l $ordr{$type} -L 1 -s $d -e $d < $file | ";
   $line .= "$WINDOW -l $T -L " . ( $T + $mspfShift ) . " -n 0 -w 5 | ";
   $line .= "$FRAME -l $mspfLength -p $mspfShift | ";
   $line .= "$WINDOW -l $mspfLength -L $mspfFFTLen -n 0 -w 3 | ";
   $line .= "$PHASE -l $mspfFFTLen -u ";

   return $line;
}

# sub routine for combining alignments
#   (taking the timings from one and the labels from the other)
sub combine_alignments {
   my ( $labelsFromAlignDir, $timingsFromAlignDir, $cmpScpFile, $alignDirOut, $labScpFileOut ) = @_;
   my ( $line, $base, $istr, $lstr, @iarr, @larr );

   make_path $alignDirOut;

   open( ISCP, "$cmpScpFile" )   || die "Cannot open file: $!";
   open( OSCP, ">$labScpFileOut" ) || die "Cannot open file: $!";

   while (<ISCP>) {
      $line = $_;
      chomp($line);
      $base = `basename $line .cmp`;
      chomp($base);

      open( LAB,  "$labelsFromAlignDir/$base.lab" )  || die "Cannot open file: $!";
      open( IFAL, "$timingsFromAlignDir/$base.lab" ) || die "Cannot open file: $!";
      open( OFAL, ">$alignDirOut/$base.lab" )        || die "Cannot open file: $!";

      while ( defined( $istr = <IFAL> ) && defined( $lstr = <LAB> ) ) {
         chomp($istr);
         chomp($lstr);
         @iarr = split( / /, $istr );
         @larr = split( / /, $lstr );
         print OFAL "$iarr[0] $iarr[1] $larr[$#larr]\n";
      }

      close(LAB);
      close(IFAL);
      close(OFAL);
      print OSCP "$alignDirOut/$base.lab\n";
   }

   close(ISCP);
   close(OSCP);
}

# sub routine for calculating statistics of modulation spectrum
sub compute_mspf_stats {
   my ( $genDir, $monoAlignDir, $natDir, $cmpScpFile, $statsDirOut ) = @_;
   my ( $cmp, $base, $type, $datDir, $natOrGen, $origDir, $line, $d );
   my ( $str, @arr, $start, $end, $find, $j );

   make_path $statsDirOut;
   $datDir = "$statsDirOut/_raw_data";
   make_path $datDir;
   foreach $natOrGen ( 'nat', 'gen' ) {
      make_path "$statsDirOut/$natOrGen";
      make_path "$datDir/$natOrGen";
   }

   # reset modulation spectrum files
   foreach $type ('mgc') {
      foreach $natOrGen ( 'nat', 'gen' ) {
         for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {
            shell("rm -f $statsDirOut/$natOrGen/${type}_dim$d.data");
            shell("touch $statsDirOut/$natOrGen/${type}_dim$d.data");
         }
      }
   }

   # calculate modulation spectrum from natural/generated sequences
   open( SCP, "$cmpScpFile" ) || die "Cannot open file: $!";
   while (<SCP>) {
      $cmp = $_;
      chomp($cmp);
      $base = `basename $cmp .cmp`;
      chomp($base);
      print " Making data from $base.lab for modulation spectrum...";

      foreach $type ('mgc') {
         foreach $natOrGen ( 'nat', 'gen' ) {

            # determine original feature directory
            if ( $natOrGen eq 'nat' ) {
               $origDir = "$natDir";
            }
            else {
               $origDir = "$genDir";
            }

            # subtract utterance-level mean
            $line = get_cmd_utmean( "$origDir/$base.$type", $type );
            shell("$line > $datDir/$natOrGen/$base.$type.mean");
            $line = get_cmd_vopr( "$origDir/$base.$type", "-s", "$datDir/$natOrGen/$base.$type.mean", $type );
            shell("$line > $datDir/$natOrGen/$base.$type.subtracted");

            # extract non-silence frames
            if ( @slnt > 0 ) {
               shell("rm -f $datDir/$natOrGen/$base.$type.subtracted.no-sil");
               shell("touch $datDir/$natOrGen/$base.$type.subtracted.no-sil");
               open( F, "$monoAlignDir/$base.lab" ) || die "Cannot open file: $!";
               while ( $str = <F> ) {
                  chomp($str);
                  @arr = split( / /, $str );
                  $find = 0;
                  for ( $j = 0 ; $j < @slnt ; $j++ ) {
                     if ( $arr[2] eq "$slnt[$j]" ) { $find = 1; last; }
                  }
                  if ( $find == 0 ) {
                     $start = int( $arr[0] * ( 1.0e-7 / ( $fs / $sr ) ) );
                     $end   = int( $arr[1] * ( 1.0e-7 / ( $fs / $sr ) ) );
                     shell("$BCUT -s $start -e $end -l $ordr{$type} < $datDir/$natOrGen/$base.$type.subtracted >> $datDir/$natOrGen/$base.$type.subtracted.no-sil");
                  }
               }
               close(F);
            }
            else {
               shell("cp $datDir/$natOrGen/$base.$type.subtracted $datDir/$natOrGen/$base.$type.subtracted.no-sil");
            }

            # calculate modulation spectrum of each dimension
            for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {
               $line = get_cmd_seq2ms( "$datDir/$natOrGen/$base.$type.subtracted.no-sil", $type, $d );
               shell("$line >> $statsDirOut/$natOrGen/${type}_dim$d.data");
            }

            shell("rm -f $datDir/$natOrGen/$base.$type.mean");
            shell("rm -f $datDir/$natOrGen/$base.$type.subtracted.no-sil");
         }
      }
      print "done\n";
   }
   close(SCP);

   # estimate modulation spectrum statistics
   foreach $type ('mgc') {
      foreach $natOrGen ( 'nat', 'gen' ) {
         for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {
            shell( "$VSTAT -o 1 -l " . ( $mspfFFTLen / 2 + 1 ) . " -d $statsDirOut/$natOrGen/${type}_dim$d.data > $statsDirOut/$natOrGen/${type}_dim$d.mean" );
            shell( "$VSTAT -o 2 -l " . ( $mspfFFTLen / 2 + 1 ) . " -d $statsDirOut/$natOrGen/${type}_dim$d.data | $SOPR -SQRT > $statsDirOut/$natOrGen/${type}_dim$d.stdd" );

            shell("rm -f $statsDirOut/$natOrGen/${type}_dim$d.data");
         }
      }
   }
}

sub train_mspf {
   my ( $modelDirIn, $monoAlignDir, $fullLabDir, $natDir ) = @_;
   my ( $modelDirOut, $corpusDir, $genDir );

   print_time("training modulation spectrum-based postfilter");

   $modelDirOut = "$modelDirIn-mspf";
   make_path $modelDirOut;

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );

   $corpusDir = get_default_corpus($modelDirIn);

   $genDir = "$modelDirOut/_gen";
   make_path $genDir;

   # make scp and fullcontext forced-aligned label files
   combine_alignments( $fullLabDir, $monoAlignDir, "$corpusDir/scp/train.scp", "$modelDirOut/_full-from-mono-fal", "$genDir/gen_fal.scp" );

   # config file for aligned parameter generation
   open( CONF, ">$genDir/apg.cnf" ) || die "Cannot open file: $!";
   print CONF "MODELALIGN = T\n";
   close(CONF);

   # synthesize speech parameters using model alignment
   shell("$HMGenS -C $cfg{'syn'} -C $genDir/apg.cnf -S $genDir/gen_fal.scp -c $pgtype -H $modelDirIn/cmp.mmf -N $modelDirIn/dur.mmf -M $genDir $modelDirIn/mlist_cmp.lst $modelDirIn/mlist_dur.lst");

   # estimate statistics for modulation spectrum
   compute_mspf_stats( $genDir, $monoAlignDir, $natDir, "$corpusDir/scp/train.scp", "$modelDirOut/stats" );

   return $modelDirOut;
}

sub get_label_type {
   my ($modelDirIn) = @_;
   my ($labelType);

   open( LABTYPE, "$modelDirIn/label_type" ) || die "Cannot open file: $!";
   $labelType = <LABTYPE>;
   chomp($labelType);
   close LABTYPE;

   return $labelType;
}

sub check_label_type {
   my ( $modelDirIn, $expectedLabelType ) = @_;
   my ($labelType);

   $labelType = get_label_type($modelDirIn);

   if ( $labelType ne $expectedLabelType ) {
      die "model should have label type $expectedLabelType (rather than $labelType): $modelDirIn";
   }
}

sub get_model_structure {
   my ($modelDirIn) = @_;
   my ($modelStructure);

   open( MODELSTRUCTURE, "$modelDirIn/model_structure" ) || die "Cannot open file: $!";
   $modelStructure = <MODELSTRUCTURE>;
   chomp($modelStructure);
   close MODELSTRUCTURE;

   return $modelStructure;
}

sub check_model_structure {
   my ( $modelDirIn, $expectedModelStructure ) = @_;
   my ($modelStructure);

   $modelStructure = get_model_structure($modelDirIn);

   if ( $modelStructure ne $expectedModelStructure ) {
      die "model should have structure $expectedModelStructure (rather than $modelStructure): $modelDirIn";
   }
}

sub check_model_structure_is_NOT {
   my ( $modelDirIn, $badModelStructure ) = @_;
   my ($modelStructure);

   $modelStructure = get_model_structure($modelDirIn);

   if ( $modelStructure eq $badModelStructure ) {
      die "model should not have structure $badModelStructure: $modelDirIn";
   }
}

sub get_default_corpus {
   my ($modelDirIn) = @_;
   my ($defaultCorpus);

   open( DC, "$modelDirIn/default_corpus" ) || die "Cannot open file: $!";
   $defaultCorpus = <DC>;
   chomp($defaultCorpus);
   close DC;

   return $defaultCorpus;
}

sub convert_model_mono_to_full {
   my ( $modelDirIn, $fullMListFile, $modelDirOut, $tag ) = @_;
   my ( $set, $phone );

   make_path $modelDirOut;

   print_time("converting monophone model to fullcontext model ($tag)");

   check_label_type( $modelDirIn, "mono" );
   check_model_structure( $modelDirIn, "list_mmf" );

   shell("echo full > $modelDirOut/label_type");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         shell("cp $fullMListFile $modelDirOut/mlist_$set.lst");

         open( EDFILE, ">$modelDirOut/_m2f_$set.hed" ) || die "Cannot open file: $!";
         open( LIST,   "$modelDirIn/mlist_$set.lst" ) || die "Cannot open file: $!";

         print EDFILE "// clone monophone models to fullcontext ones\n";
         print EDFILE "CL \"$fullMListFile\"\n\n";    # CLone monophone to fullcontext

         print EDFILE "// tie state transition probability\n";
         while ( $phone = <LIST> ) {
            chomp($phone);
            print EDFILE "TI T_${phone} {*-${phone}+*.transP}\n";    # TIe transition prob
         }
         close(LIST);
         close(EDFILE);

         shell("$HHEd{'trn'} -B -T 1 -H $modelDirIn/$set.mmf -w $modelDirOut/$set.mmf $modelDirOut/_m2f_$set.hed $modelDirIn/mlist_$set.lst");
      }
   }
}

sub convert_model_clus_to_full {
   my ( $modelDirIn, $modelDirOut, $tag ) = @_;
   my ($set);

   make_path $modelDirOut;

   print_time("converting clustered model to fullcontext model ($tag)");

   check_label_type( $modelDirIn, "full" );
   check_model_structure( $modelDirIn, "clus_mmf" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         shell("cp $modelDirIn/mlist_$set.lst $modelDirOut/");

         make_edfile_untie( $set, "$modelDirOut/_untie_$set.hed" );
         shell("$HHEd{'trn'} -B -T 1 -H $modelDirIn/$set.mmf -w $modelDirOut/$set.mmf $modelDirOut/_untie_$set.hed $modelDirIn/mlist_$set.lst");
      }
   }
}

sub convert_model_list_sep_to_list_mmf {
   my ( $modelDirIn, $modelDirOut, $tag ) = @_;
   my ( $set, $type );
   my ( $macroFile, @macroFiles, $macrosString );

   make_path $modelDirOut;

   print_time("converting list_sep model to list_mmf model ($tag)");

   check_model_structure( $modelDirIn, "list_sep" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("echo list_mmf > $modelDirOut/model_structure");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         shell("cp $modelDirIn/mlist_$set.lst $modelDirOut/");

         open( EDFILE, ">$modelDirOut/_make_mmf_$set.hed" ) || die "Cannot open file: $!";
         close(EDFILE);

         @macroFiles = glob "$modelDirIn/${set}_macro/*";
         $macrosString = "";
         foreach $macroFile (@macroFiles) {
            $macrosString .= " -H $macroFile";
         }

         shell("$HHEd{'trn'} -T 1$macrosString -d $modelDirIn/$set -w $modelDirOut/$set.mmf $modelDirOut/_make_mmf_$set.hed $modelDirIn/mlist_$set.lst");
      }
   }
}

sub convert_model_clone_average_to_list_sep {
   my ( $modelDirIn, $newMListFile, $newLabelType, $modelDirOut, $tag ) = @_;

   make_path $modelDirOut;

   print_time("cloning average model to a list_sep model for label type $newLabelType ($tag)");

   check_label_type( $modelDirIn, "none" );
   check_model_structure( $modelDirIn, "list_sep" );

   shell("echo $newLabelType > $modelDirOut/label_type");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         shell("cp $newMListFile $modelDirOut/mlist_$set.lst");

         make_path "$modelDirOut/$set";
         make_path "$modelDirOut/${set}_macro";
         shell("cp $modelDirIn/${set}_macro/* $modelDirOut/${set}_macro/");
      }
   }

   open( LIST, $newMListFile ) || die "Cannot open file: $!";
   while ( $phone = <LIST> ) {
      chomp($phone);
      foreach $set ('cmp', 'dur') {
         if ( -e "$modelDirIn/mlist_$set.lst" ) {
            open( SRC, "$modelDirIn/$set/average" )  || die "Cannot open file: $!";
            open( TGT, ">$modelDirOut/$set/$phone" ) || die "Cannot open file: $!";
            while ( $str = <SRC> ) {
               if ( index( $str, "~h" ) == 0 ) {
                  print TGT "~h \"$phone\"\n";
               }
               else {
                  print TGT "$str";
               }
            }
            close(TGT);
            close(SRC);
         }
      }
   }
   close(LIST);
}

sub convert_model_clone_average_to_list_mmf {
   my ( $modelDirIn, $newMListFile, $newLabelType, $modelDirOut, $tag ) = @_;

   make_path $modelDirOut;

   print_time("cloning average model to a list_mmf model for label type $newLabelType ($tag)");

   check_label_type( $modelDirIn, "none" );
   check_model_structure( $modelDirIn, "list_sep" );

   shell("echo $newLabelType > $modelDirOut/label_type");
   shell("echo list_mmf > $modelDirOut/model_structure");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         shell("cp $newMListFile $modelDirOut/mlist_$set.lst");

         shell("cat $modelDirIn/${set}_macro/* > $modelDirOut/$set.mmf");
      }
   }

   # N.B. code below produces mmf files with lots of repeated "~o" macros, but
   #   the HTK / HTS tools don't seem to mind this.

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         open( TGT, ">>$modelDirOut/$set.mmf" ) || die "Cannot open file: $!";
         open( LIST, $newMListFile ) || die "Cannot open file: $!";
         while ( $phone = <LIST> ) {
            chomp($phone);

            open( SRC, "$modelDirIn/$set/average" )  || die "Cannot open file: $!";
            while ( $str = <SRC> ) {
               if ( index( $str, "~h" ) == 0 ) {
                  print TGT "~h \"$phone\"\n";
               }
               else {
                  print TGT "$str";
               }
            }
            close(SRC);
         }
         close(LIST);
         close(TGT);
      }
   }
}

# Adds an explicit label model for each unseen label in a corpus.
sub convert_model_add_unseen {
   my ( $modelDirIn, $allMListFile, $modelDirOut, $tag ) = @_;
   my ( $set, $type );

   make_path $modelDirOut;

   print_time("making unseen models ($tag)");

   check_model_structure( $modelDirIn, "clus_mmf" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         foreach $type ( @{ $ref{$set} } ) {
            shell("cp $modelDirIn/${set}_$type.inf $modelDirOut/");
         }

         shell("cat $allMListFile > $modelDirOut/_mlist_all_$set.lst");

         open( EDFILE, ">$modelDirOut/_mkunseen_$set.hed" ) || die "Cannot open file: $!";
         print EDFILE "\nTR 2\n\n";
         foreach $type ( @{ $ref{$set} } ) {
            print EDFILE "// load trees for $type\n";
            print EDFILE "LT \"$modelDirIn/${set}_$type.inf\"\n\n";
         }
         print EDFILE "// make unseen model\n";
         print EDFILE "AU \"$modelDirOut/_mlist_all_$set.lst\"\n\n";
         print EDFILE "// make model compact\n";
         print EDFILE "CO \"$modelDirOut/mlist_$set.lst\"\n\n";
         close(EDFILE);

         shell("$HHEd{'trn'} -B -T 1 -H $modelDirIn/$set.mmf -w $modelDirOut/$set.mmf $modelDirOut/_mkunseen_$set.hed $modelDirIn/mlist_$set.lst");
      }
   }
}

# Converts a prototype model to an average model using HCompV.
sub get_average_model {
   my ( $modelDirIn, $modelDirOut, $tag ) = @_;
   my ( $corpusDir, $macroFile, @macroFiles, $macrosString );

   make_path $modelDirOut;
   make_path "$modelDirOut/cmp";
   make_path "$modelDirOut/cmp_macro";

   print_time("making average model and computing variance floors ($tag)");

   check_label_type( $modelDirIn, "none" );
   check_model_structure( $modelDirIn, "list_sep" );

   shell("echo none > $modelDirOut/label_type");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   shell("echo average > $modelDirOut/mlist_cmp.lst");

   $corpusDir = get_default_corpus($modelDirIn);

   @macroFiles = glob "$modelDirIn/cmp_macro/*";
   $macrosString = "";
   foreach $macroFile (@macroFiles) {
      $macrosString .= " -H $macroFile";
   }

   # make average model and compute variance floors
   shell("$HCompV$macrosString -S $corpusDir/scp/train.scp -M $modelDirOut/cmp_macro -o average $modelDirIn/cmp/average");
   shell("mv $modelDirOut/cmp_macro/average $modelDirOut/cmp/");
   shell("mv $modelDirOut/cmp_macro/vFloors $modelDirOut/cmp_macro/1-vfloor");
}

# Generates a prototype model.
sub make_proto_model {
   my ( $defaultCorpusDirIn, $modelDirOut, $tag ) = @_;
   my ( $i, $j, $k, $s );

   make_path $modelDirOut;
   make_path "$modelDirOut/cmp";
   make_path "$modelDirOut/cmp_macro";

   print_time("making prototype model ($tag)");

   shell("echo none > $modelDirOut/label_type");
   shell("echo list_sep > $modelDirOut/model_structure");
   shell("echo $defaultCorpusDirIn > $modelDirOut/default_corpus");

   shell("echo average > $modelDirOut/mlist_cmp.lst");

   open( GLOBAL, ">$modelDirOut/cmp_macro/0-global" ) || die "Cannot open file: $!";
   print GLOBAL "~o\n";
   print GLOBAL "<STREAMINFO> $nstream{'cmp'}{'total'}";
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         printf GLOBAL " %d", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
      }
   }
   print GLOBAL "\n";
   print GLOBAL "<MSDINFO> $nstream{'cmp'}{'total'}";
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         print GLOBAL " $msdi{$type}";
      }
   }
   print GLOBAL "\n";
   print GLOBAL "<VECSIZE> $vSize{'cmp'}{'total'}<NULLD><USER><DIAGC>\n";
   close(GLOBAL);

   open( STRW, ">$modelDirOut/cmp_macro/2-stream_weight" ) || die "Cannot open file: $!";
   print STRW "~w \"SW_all\"\n";
   print STRW "<SWEIGHTS> $nstream{'cmp'}{'total'}\n";
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         print STRW " $strw{$type}";
      }
   }
   print STRW "\n";
   close(STRW);

   open( PROTO, ">$modelDirOut/cmp/average" ) || die "Cannot open file: $!";
   print PROTO "<BEGINHMM>\n";
   printf PROTO "<NUMSTATES> %d\n", $nState + 2;
   for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {
      print PROTO "<STATE> $i\n";
      print PROTO "~w \"SW_all\"\n";
      foreach $type (@cmp) {
         for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
            print PROTO "<STREAM> $s\n";
            if ( $msdi{$type} == 0 ) {    # non-MSD stream
                                          # output mean vector
               printf PROTO "<MEAN> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
               for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
                  print PROTO " 0.000000e+00";
               }
               print PROTO "\n";

               # output covariance matrix (diag)
               printf PROTO "<VARIANCE> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
               for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
                  print PROTO " 1.000000e+00";
               }
               print PROTO "\n";
            }
            else {    # MSD stream
                      # output MSD
               print PROTO "<NUMMIXES> 2\n";

               # output 1st space (non 0-dimensional space)
               # output space weights
               print PROTO "<MIXTURE> 1 5.000000e-01\n";

               # output mean vector
               printf PROTO "<MEAN> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
               for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
                  print PROTO " 0.000000e+00";
               }
               print PROTO "\n";

               # output covariance matrix (diag)
               printf PROTO "<VARIANCE> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
               for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
                  print PROTO " 1.000000e+00";
               }
               print PROTO "\n";

               # output 2nd space (0-dimensional space)
               print PROTO "<MIXTURE> 2 5.000000e-01\n";
               print PROTO "<MEAN> 0\n";
               print PROTO "<VARIANCE> 0\n";
            }
         }
      }
   }
   printf PROTO "<TRANSP> %d\n", $nState + 2;
   for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
      print PROTO " 1.000000e+00" if ( $j == 2 );
      print PROTO " 0.000000e+00" if ( $j != 2 );
   }
   print PROTO "\n";
   for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {
      for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
         print PROTO " 6.000000e-01" if ( $i == $j );
         print PROTO " 4.000000e-01" if ( $i == $j - 1 );
         print PROTO " 0.000000e+00" if ( $i != $j && $i != $j - 1 );
      }
      print PROTO "\n";
   }
   for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
      print PROTO " 0.000000e+00";
   }
   print PROTO "\n";
   print PROTO "<ENDHMM>\n";
   close(PROTO);
}

# Generates a prototype GV model.
sub make_proto_model_gv {
   my ( $defaultCorpusDirIn, $modelDirOut, $tag ) = @_;
   my ( $s, $type, $k );

   make_path $modelDirOut;
   make_path "$modelDirOut/cmp";
   make_path "$modelDirOut/cmp_macro";

   print_time("making prototype GV model ($tag)");

   shell("echo none > $modelDirOut/label_type");
   shell("echo list_sep > $modelDirOut/model_structure");
   shell("echo $defaultCorpusDirIn > $modelDirOut/default_corpus");

   shell("echo average > $modelDirOut/mlist_cmp.lst");

   open( GLOBAL, ">$modelDirOut/cmp_macro/0-global" ) || die "Cannot open file: $!";
   print GLOBAL "~o\n";
   print GLOBAL "<STREAMINFO> $nPdfStreams{'cmp'}";
   foreach $type (@cmp) {
      print GLOBAL " $ordr{$type}";
   }
   print GLOBAL "\n";
   print GLOBAL "<MSDINFO> $nPdfStreams{'cmp'}";
   foreach $type (@cmp) {
      print GLOBAL " 0";
   }
   print GLOBAL "\n";
   $s = 0;
   foreach $type (@cmp) {
      $s += $ordr{$type};
   }
   print GLOBAL "<VECSIZE> $s<NULLD><USER><DIAGC>\n";
   close(GLOBAL);

   open( PROTO, ">$modelDirOut/cmp/average" ) || die "Cannot open file: $!";
   print PROTO "<BEGINHMM>\n";
   print PROTO "<NUMSTATES> 3\n";
   print PROTO "<STATE> 2\n";
   $s = 1;
   foreach $type (@cmp) {
      print PROTO "<STREAM> $s\n";
      print PROTO "<MEAN> $ordr{$type}\n";
      for ( $k = 1 ; $k <= $ordr{$type} ; $k++ ) {
         print PROTO " 0.000000e+00";
      }
      print PROTO "\n";
      print PROTO "<VARIANCE> $ordr{$type}\n";
      for ( $k = 1 ; $k <= $ordr{$type} ; $k++ ) {
         print PROTO " 1.000000e+00";
      }
      print PROTO "\n";
      $s++;
   }
   print PROTO "<TRANSP> 3\n";
   print PROTO " 0.000000e+00 1.000000e+00 0.000000e+00\n";
   print PROTO " 0.000000e+00 0.000000e+00 1.000000e+00\n";
   print PROTO " 0.000000e+00 0.000000e+00 0.000000e+00\n";
   print PROTO "<ENDHMM>\n";
   close(PROTO);
}

# Applies variance floors to a list_sep model (operates in-place).
sub edit_model_apply_vfloor {
   my ( $modelDir, $set ) = @_;
   my ( $phone, $dirNew );
   my ( $macroFile, @macroFiles, $macrosString );

   check_model_structure( $modelDir, "list_sep" );

   if ( -e "$modelDir/${set}_macro/1-vfloor" ) {
      open( EDFILE, ">$modelDir/_apply_vfloor_$set.hed" ) || die "Cannot open file: $!";
      print EDFILE "FV \"$modelDir/${set}_macro/1-vfloor\"\n";
      close(EDFILE);

      @macroFiles = glob "$modelDir/${set}_macro/*";
      $macrosString = "";
      foreach $macroFile (@macroFiles) {
         $macrosString .= " -H $macroFile";
      }
      open( LIST, "$modelDir/mlist_$set.lst" ) || die "Cannot open file: $!";
      while ( $phone = <LIST> ) {
         chomp($phone);
         $macrosString .= " -H $modelDir/$set/$phone";
      }
      close(LIST);

      shell("$HHEd{'trn'} -T 1$macrosString -M $modelDir/$set $modelDir/_apply_vfloor_$set.hed $modelDir/mlist_$set.lst");

      foreach $macroFile (@macroFiles) {
         shell("rm $modelDir/$set/`basename $macroFile`");
      }
   }
}

# Initializes a model from provided alignments using HInit and HRest.
sub initialize_model_from_alignments {
   my ( $modelDirIn, $tag ) = @_;
   my ( $modelDirOut, $corpusDir, $set, $phone );
   my ( $macroFile, @macroFiles, $macrosString );

   print_time("initializing model from provided alignments ($tag)");

   $modelDirOut = "$modelDirIn-init";
   make_path $modelDirOut;

   check_label_type( $modelDirIn, "mono" );
   check_model_structure( $modelDirIn, "list_sep" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   shell("cp $modelDirIn/mlist_cmp.lst $modelDirOut/");
   shell("cp $modelDirOut/mlist_cmp.lst $modelDirOut/mlist_dur.lst");

   make_path "$modelDirOut/cmp";
   make_path "$modelDirOut/cmp_macro";
   make_path "$modelDirOut/dur";
   make_path "$modelDirOut/dur_macro";

   if ( -e "$modelDirIn/mlist_dur.lst" ) {
      shell("cp $modelDirIn/dur_macro/* $modelDirOut/dur_macro/");
   }

   $corpusDir = get_default_corpus($modelDirIn);

   @macroFiles = glob "$modelDirIn/cmp_macro/*";
   $macrosString = "";
   foreach $macroFile (@macroFiles) {
      $macrosString .= " -H $macroFile";
   }

   open( LIST, "$modelDirIn/mlist_cmp.lst" ) || die "Cannot open file: $!";
   while ( $phone = <LIST> ) {
      chomp($phone);
      if ( grep( $_ eq $phone, keys %mdcp ) <= 0 ) {
         print "--------------- $phone ----------------\n";
         shell("$HInit$macrosString -M $modelDirOut/cmp_macro -I $corpusDir/labels/mono.mlf -S $corpusDir/scp/train.scp -l $phone -o $phone $modelDirIn/cmp/$phone");
         shell("$HRest$macrosString -M $modelDirOut/cmp_macro -I $corpusDir/labels/mono.mlf -S $corpusDir/scp/train.scp -l $phone -g $modelDirOut/dur/$phone $modelDirOut/cmp_macro/$phone");
         shell("mv $modelDirOut/cmp_macro/$phone $modelDirOut/cmp/");
      }
   }
   close(LIST);

   if ( -e "$modelDirIn/mlist_dur.lst" ) {
      print "--------------- (applying duration variance floors) ----------------\n";
      # apply duration variance floors
      #   (could be considered a bug in HRest that it does not use config variables
      #   related to variance flooring of the duration model)
      edit_model_apply_vfloor( $modelDirOut, "dur" );
   }

   open( LIST, "$modelDirIn/mlist_cmp.lst" ) || die "Cannot open file: $!";
   while ( $phone = <LIST> ) {
      chomp($phone);
      if ( grep( $_ eq $phone, keys %mdcp ) > 0 ) {
         print "--------------- $phone ----------------\n";
         print "using $mdcp{$phone} instead of $phone\n";
         foreach $set ('cmp', 'dur') {
            open( SRC, "$modelDirOut/$set/$mdcp{$phone}" ) || die "Cannot open file: $!";
            open( TGT, ">$modelDirOut/$set/$phone" )       || die "Cannot open file: $!";
            while (<SRC>) {
               s/~h \"$mdcp{$phone}\"/~h \"$phone\"/;
               print TGT;
            }
            close(TGT);
            close(SRC);
         }
      }
   }
   close(LIST);

   return $modelDirOut;
}

sub expectation_maximization {
   my ( $modelDirIn, $numIts, $tag ) = @_;
   my ( $modelDirOut, $corpusDir, $labelType, $mlfFile, $binaryFlag, $set, $type, $dirIn, $it );

   print_time("embedded reestimation ($tag)");

   $modelDirOut = "$modelDirIn-$numIts";
   make_path $modelDirOut;

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         shell("cp $modelDirIn/mlist_$set.lst $modelDirOut/");
      }
   }

   $corpusDir = get_default_corpus($modelDirIn);

   $labelType = get_label_type($modelDirIn);
   if ( $labelType eq "mono" ) {
      $mlfFile = "$corpusDir/labels/mono.mlf";
      $binaryFlag = "";
   }
   else {
      $mlfFile = "$corpusDir/labels/full.mlf";
      $binaryFlag = "-B";
   }

   if ( get_model_structure($modelDirIn) eq "clus_mmf" ) {
      foreach $set ('cmp', 'dur') {
         if ( -e "$modelDirIn/mlist_$set.lst" ) {
            foreach $type ( @{ $ref{$set} } ) {
               shell("cp $modelDirIn/${set}_$type.inf $modelDirOut/");
            }
         }
      }
   }

   $dirIn = $modelDirIn;
   for ( $it = 1 ; $it <= $numIts ; $it++ ) {
      print("\n\nIteration $it of Embedded Re-estimation\n");
      if ( -e "$modelDirIn/mlist_dur.lst" ) {
         shell("$HERest{'trn'} $binaryFlag -I $mlfFile -S $corpusDir/scp/train.scp -H $dirIn/cmp.mmf -N $dirIn/dur.mmf -M $modelDirOut -R $modelDirOut $dirIn/mlist_cmp.lst $dirIn/mlist_dur.lst");
      }
      else {
         shell("$HERest{'trn'} $binaryFlag -I $mlfFile -S $corpusDir/scp/train.scp -H $dirIn/cmp.mmf -M $modelDirOut $dirIn/mlist_cmp.lst");
      }

      $dirIn = $modelDirOut;
   }

   return $modelDirOut;
}

sub expectation_maximization_deterministic_annealing {
   my ( $modelDirIn, $numItsOuter, $numItsInner, $tag ) = @_;
   my ( $modelDirOut, $corpusDir, $labelType, $mlfFile, $binaryFlag, $set, $type, $dirIn, $it );

   print_time("embedded reestimation using deterministic annealing ($tag)");

   $modelDirOut = "$modelDirIn-daem_${numItsOuter}_$numItsInner";
   make_path $modelDirOut;

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      if ( -e "$modelDirIn/mlist_$set.lst" ) {
         shell("cp $modelDirIn/mlist_$set.lst $modelDirOut/");
      }
   }

   $corpusDir = get_default_corpus($modelDirIn);

   $labelType = get_label_type($modelDirIn);
   if ( $labelType eq "mono" ) {
      $mlfFile = "$corpusDir/labels/mono.mlf";
      $binaryFlag = "";
   }
   else {
      $mlfFile = "$corpusDir/labels/full.mlf";
      $binaryFlag = "-B";
   }

   if ( get_model_structure($modelDirIn) eq "clus_mmf" ) {
      foreach $set ('cmp', 'dur') {
         if ( -e "$modelDirIn/mlist_$set.lst" ) {
            foreach $type ( @{ $ref{$set} } ) {
               shell("cp $modelDirIn/${set}_$type.inf $modelDirOut/");
            }
         }
      }
   }

   $dirIn = $modelDirIn;
   for ( $itOuter = 1 ; $itOuter <= $numItsOuter ; $itOuter++ ) {
      for ( $itInner = 1 ; $itInner <= $numItsInner ; $itInner++ ) {
         $temperature = ( $itOuter / $numItsOuter ) ** $daem_alpha;
         print("\n\nIteration $itOuter.$itInner of DAEM (temperature = $temperature)\n");
         if ( -e "$modelDirIn/mlist_dur.lst" ) {
            shell("$HERest{'trn'} $binaryFlag -I $mlfFile -S $corpusDir/scp/train.scp -k $temperature -H $dirIn/cmp.mmf -N $dirIn/dur.mmf -M $modelDirOut -R $modelDirOut $dirIn/mlist_cmp.lst $dirIn/mlist_dur.lst");
         }
         else {
            shell("$HERest{'trn'} $binaryFlag -I $mlfFile -S $corpusDir/scp/train.scp -k $temperature -H $dirIn/cmp.mmf -M $modelDirOut $dirIn/mlist_cmp.lst");
         }

         $dirIn = $modelDirOut;
      }
   }

   return $modelDirOut;
}

sub decision_tree_cluster {
   # FIXME : remove isGVFIXME hack
   my ( $modelDirIn, $tag, $isGVFIXME ) = @_;
   my ( $modelDirOut, $accModelDir, $labelType, $corpusDir, $set, $type, $phone );

   $modelDirOut = "$modelDirIn-clus";
   make_path $modelDirOut;

   $accModelDir = "$modelDirOut/_acc";

   # convert the incoming model to a full list_mmf model ready for accumulation
   $labelType = get_label_type($modelDirIn);
   if ( $labelType eq "mono" ) {
      check_model_structure( $modelDirIn, "list_mmf" );

      convert_model_mono_to_full( $modelDirIn, $lst{'ful'}, $accModelDir, $tag );
   }
   else {
      if ( get_model_structure($modelDirIn) eq "clus_mmf" ) {
         convert_model_clus_to_full( $modelDirIn, $accModelDir, $tag );
      }
      else {
         check_model_structure( $modelDirIn, "list_mmf" );

         shell("rsync -r $modelDirIn/ $accModelDir");
      }
   }

   $corpusDir = get_default_corpus($accModelDir);

   print_time("fullcontext embedded reestimation ($tag)");

   print("\n\nEmbedded Re-estimation\n");
   if ( -e "$accModelDir/mlist_dur.lst" ) {
      shell("$HERest{'trn'} -B -I $corpusDir/labels/full.mlf -S $corpusDir/scp/train.scp -H $accModelDir/cmp.mmf -N $accModelDir/dur.mmf -M $accModelDir -R $accModelDir -C $cfg{'nvf'} -s $accModelDir/cmp.stats -w 0.0 $accModelDir/mlist_cmp.lst $accModelDir/mlist_dur.lst");
   }
   else {
      shell("$HERest{'trn'} -B -I $corpusDir/labels/full.mlf -S $corpusDir/scp/train.scp -H $accModelDir/cmp.mmf -M $accModelDir -C $cfg{'nvf'} -s $accModelDir/cmp.stats -w 0.0 $accModelDir/mlist_cmp.lst");
   }

   print_time("tree-based context clustering ($tag)");

   if ( -e "$accModelDir/mlist_dur.lst" ) {
      # convert cmp stats to duration ones
      convstats( "$accModelDir/cmp.stats", "$accModelDir/dur.stats" );
   }

   shell("cp $accModelDir/label_type $modelDirOut/");
   shell("echo clus_mmf > $modelDirOut/model_structure");
   shell("cp $accModelDir/default_corpus $modelDirOut/");
   shell("cp $accModelDir/mlist_cmp.lst $modelDirOut/");
   if ( -e "$accModelDir/mlist_dur.lst" ) {
      shell("cp $accModelDir/mlist_dur.lst $modelDirOut/");
   }

   foreach $set ('cmp', 'dur') {
      if ( -e "$accModelDir/mlist_$set.lst" ) {
         shell("mv $accModelDir/$set.mmf $modelDirOut/$set.mmf");

         foreach $type ( @{ $ref{$set} } ) {
            if ( $isGVFIXME ) {
               make_edfile_state_gv( $type, "$accModelDir/$set.stats", "$modelDirOut/cxc_${set}_$type.hed", "$modelDirOut/${set}_$type.inf" );
               shell("$HHEd{'trn'} -B -T 3 -C $cfg{$type} -H $modelDirOut/$set.mmf $gvmdl{$type} -w $modelDirOut/$set.mmf $modelDirOut/cxc_${set}_$type.hed $modelDirOut/mlist_$set.lst");
            }
            else {
               make_edfile_state( $type, "$accModelDir/$set.stats", "$modelDirOut/cxc_${set}_$type.hed", "$modelDirOut/${set}_$type.inf" );
               shell("$HHEd{'trn'} -B -T 3 -C $cfg{$type} -H $modelDirOut/$set.mmf $mdl{$type} -w $modelDirOut/$set.mmf $modelDirOut/cxc_${set}_$type.hed $modelDirOut/mlist_$set.lst");
            }
         }
      }
   }

   shell("rm -rf $accModelDir");

   return $modelDirOut;
}

sub repeated_clustering_and_em {
   my ( $modelDirIn, $numClusterings, $numItsEmPerClustering, $tag, $isGVFIXME ) = @_;
   my ( $dirCurr, $clustering );

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );

   $dirCurr = $modelDirIn;
   for ( $clustering = 1 ; $clustering <= $numClusterings ; $clustering++ ) {
      $dirCurr = decision_tree_cluster( $dirCurr, "$tag$clustering", $isGVFIXME );
      $dirCurr = expectation_maximization( $dirCurr, $numItsEmPerClustering, "$tag$clustering" );
   }

   return $dirCurr;
}

# Converts a cmp model to a cmp+dur model by adding a Gaussian duration model.
sub add_simple_dur {
   my ( $modelDirIn, $mean, $variance, $modelDirOut, $tag ) = @_;
   my ( $i, $j );

   make_path $modelDirOut;

   print_time("converting cmp model to cmp+dur model ($tag)");

   check_label_type( $modelDirIn, "none" );
   check_model_structure( $modelDirIn, "list_sep" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   shell("cp $modelDirIn/mlist_cmp.lst $modelDirOut/");
   shell("echo average > $modelDirOut/mlist_dur.lst");

   make_path "$modelDirOut/cmp";
   make_path "$modelDirOut/cmp_macro";
   make_path "$modelDirOut/dur";
   make_path "$modelDirOut/dur_macro";

   shell("cp $modelDirIn/cmp/* $modelDirOut/cmp/");
   shell("cp $modelDirIn/cmp_macro/* $modelDirOut/cmp_macro/");

   # output global macro for duration model
   open( GLOBAL, ">$modelDirOut/dur_macro/0-global" ) || die "Cannot open file: $!";
   print GLOBAL "~o\n";
   print GLOBAL "<STREAMINFO> $nState";
   for ( $i = 1 ; $i <= $nState ; $i++ ) {
      print GLOBAL " 1";
   }
   print GLOBAL "\n";
   print GLOBAL "<VECSIZE> ${nState}<NULLD><USER><DIAGC>\n";
   close(GLOBAL);

   # output variance flooring macro for duration model
   open( VF, ">$modelDirOut/dur_macro/1-vfloor" ) || die "Cannot open file: $!";
   for ( $i = 1 ; $i <= $nState ; $i++ ) {
      print VF "~v varFloor$i\n";
      print VF "<Variance> 1\n";
      $j = $variance * $vflr{'dur'};
      print VF " $j\n";
   }
   close(VF);

   # output average model for duration model
   open( MMF, ">$modelDirOut/dur/average" ) || die "Cannot open file: $!";
   print MMF "~h \"average\"\n";
   print MMF "<BEGINHMM>\n";
   print MMF "<NUMSTATES> 3\n";
   print MMF "<STATE> 2\n";
   for ( $i = 1 ; $i <= $nState ; $i++ ) {
      print MMF "<STREAM> $i\n";
      print MMF "<MEAN> 1\n";
      print MMF " $mean\n";
      print MMF "<VARIANCE> 1\n";
      print MMF " $variance\n";
   }
   print MMF "<TRANSP> 3\n";
   print MMF " 0.0 1.0 0.0\n";
   print MMF " 0.0 0.0 1.0\n";
   print MMF " 0.0 0.0 0.0\n";
   print MMF "<ENDHMM>\n";
   close(MMF);
}

sub add_1_mix_comp {
   my ( $modelDirIn, $tag ) = @_;
   my ($modelDirOut);

   print_time("increasing the number of mixture components ($tag)");

   $modelDirOut = "$modelDirIn-mix+1";
   make_path $modelDirOut;

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      shell("cp $modelDirIn/mlist_$set.lst $modelDirOut/");
   }

   if ( get_model_structure($modelDirIn) eq "clus_mmf" ) {
      foreach $set ('cmp', 'dur') {
         foreach $type ( @{ $ref{$set} } ) {
            shell("cp $modelDirIn/${set}_$type.inf $modelDirOut/");
         }
      }
   }

   make_edfile_upmix( "cmp", "$modelDirOut/_upmix_cmp.hed" );
   shell("$HHEd{'trn'} -B -T 1 -H $modelDirIn/cmp.mmf -w $modelDirOut/cmp.mmf $modelDirOut/_upmix_cmp.hed $modelDirIn/mlist_cmp.lst");

   shell("cp $modelDirIn/dur.mmf $modelDirOut/");

   return $modelDirOut;
}

sub estimate_semi_tied_cov {
   my ( $modelDirIn, $tag ) = @_;
   my ( $modelDirOut, $corpusDir, $opt );

   print_time("semi-tied covariance matrices ($tag)");

   $modelDirOut = "$modelDirIn-stc";
   make_path $modelDirOut;

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/model_structure $modelDirOut/");
   shell("cp $modelDirIn/default_corpus $modelDirOut/");

   foreach $set ('cmp', 'dur') {
      shell("cp $modelDirIn/mlist_$set.lst $modelDirOut/");
   }

   if ( get_model_structure($modelDirIn) eq "clus_mmf" ) {
      foreach $set ('cmp', 'dur') {
         foreach $type ( @{ $ref{$set} } ) {
            shell("cp $modelDirIn/${set}_$type.inf $modelDirOut/");
         }
      }
   }

   $corpusDir = get_default_corpus($modelDirIn);

   make_stc_base("$modelDirOut/_stc.base");
   make_stc_config( "$modelDirOut/_stc.base", "$modelDirOut/_stc.cnf" );

   $opt = "-C $modelDirOut/_stc.cnf -K $modelDirOut stc -u smvdmv";

   shell("$HERest{'trn'} -B -I $corpusDir/labels/full.mlf -S $corpusDir/scp/train.scp -H $modelDirIn/cmp.mmf -N $modelDirIn/dur.mmf -M $modelDirOut -R $modelDirOut $opt $modelDirIn/mlist_cmp.lst $modelDirIn/mlist_dur.lst");

   return $modelDirOut;
}

sub fal_on_train_corpus {
   my ( $modelDirIn, $tag ) = @_;
   my ( $dirOut, $corpusDir, $labelType, $mlfFile );

   print_time("forced alignment ($tag)");

   $dirOut = "$modelDirIn-fal";
   make_path $dirOut;

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );

   $corpusDir = get_default_corpus($modelDirIn);

   $labelType = get_label_type($modelDirIn);
   if ( $labelType eq "mono" ) {
      $mlfFile = "$corpusDir/labels/mono.mlf";
   }
   else {
      $mlfFile = "$corpusDir/labels/full.mlf";
   }

   shell("$HSMMAlign -I $mlfFile -S $corpusDir/scp/train.scp -H $modelDirIn/cmp.mmf -N $modelDirIn/dur.mmf -m $dirOut $modelDirIn/mlist_cmp.lst $modelDirIn/mlist_dur.lst");

   return $dirOut;
}

sub eval_model {
   my ( $modelDirIn, $evalMListFile, $evalCmpScpFile, $tag ) = @_;
   my ( $dirOut, $allModelDir, $labelType, $mlfFile );

   $dirOut = "$modelDirIn-eval";
   make_path $dirOut;

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );

   if ( get_model_structure($modelDirIn) eq "clus_mmf" ) {
      convert_model_add_unseen( $modelDirIn, $evalMListFile, "$dirOut/_all", $tag );
      $allModelDir = "$dirOut/_all";
   }
   else {
      $allModelDir = $modelDirIn;
   }

   $labelType = get_label_type($modelDirIn);
   if ( $labelType eq "mono" ) {
      $mlfFile = $mlf{'mon'};
   }
   else {
      $mlfFile = $mlf{'ful'};
   }

   print_time("computing test set log probability ($tag)");

   if (-s $evalCmpScpFile) {
      shell("$HERest{'tst'} -I $mlfFile -S $evalCmpScpFile -H $allModelDir/cmp.mmf -N $allModelDir/dur.mmf -M /dev/null -R /dev/null $allModelDir/mlist_cmp.lst $allModelDir/mlist_dur.lst");
   }
   else {
      print("(skipping since specified corpus is empty)\n\n");
   }

   # FIXME : write summary of TSLP to a file

   print_time("forced alignment on test corpus ($tag)");

   make_path "$dirOut/fal";

   shell("$HSMMAlign -I $mlfFile -S $evalCmpScpFile -H $allModelDir/cmp.mmf -N $allModelDir/dur.mmf -m $dirOut/fal $allModelDir/mlist_cmp.lst $allModelDir/mlist_dur.lst");

   # FIXME : remove _all directory

   return $dirOut;
}

sub synthesize {
   my ( $modelDirIn, $genMListFile, $genLabScpFile, $genMethod, $genType, $gvModelDirIn, $tag ) = @_;
   my ( $dirOut, $synthDir, $useGv, $useCdGv, $allModelDir, $gvAllModelDir );

   $dirOut = "$modelDirIn-synth";
   make_path $dirOut;

   check_model_structure_is_NOT( $modelDirIn, "list_sep" );
   check_model_structure_is_NOT( $gvModelDirIn, "list_sep" );

   $useGv = ( $gvModelDirIn ne "" );
   $useCdGv = ( get_label_type($gvModelDirIn) ne "none" );

   if ( get_model_structure($modelDirIn) eq "clus_mmf" ) {
      convert_model_add_unseen( $modelDirIn, $genMListFile, "$dirOut/_all", $tag );
      $allModelDir = "$dirOut/_all";
   }
   else {
      $allModelDir = $modelDirIn;
   }

   if ( get_model_structure($gvModelDirIn) eq "clus_mmf" ) {
      # FIXME : this overgenerates unseen models since only the first label
      #   in a label file is ever used
      convert_model_add_unseen( $gvModelDirIn, $genMListFile, "$dirOut/_gv_all", $tag );
      $gvAllModelDir = "$dirOut/_gv_all";
   }
   else {
      $gvAllModelDir = $gvModelDirIn;
   }

   # FIXME : actually use genMethod, and add more possible generation methods
   $synthDir = "$dirOut/$genMethod-c$genType";
   make_path $synthDir;

   print_time("generating speech parameter sequences ($tag)");

   # config file for parameter generation
   open( CONF, ">$synthDir/_syn.cnf" ) || die "Cannot open file: $!";
   print CONF "NATURALREADORDER = T\n";
   print CONF "NATURALWRITEORDER = T\n";
   print CONF "USEALIGN = T\n";
   # prevent very verbose output during GV generation
   print CONF "HGEN:TRACE = 0\n";
   print CONF "PDFSTRSIZE = \"IntVec $nPdfStreams{'cmp'}";    # PdfStream structure
   foreach $type (@cmp) {
      print CONF " $nstream{'cmp'}{$type}";
   }
   print CONF "\"\n";
   print CONF "PDFSTRORDER = \"IntVec $nPdfStreams{'cmp'}";    # order of each PdfStream
   foreach $type (@cmp) {
      print CONF " $ordr{$type}";
   }
   print CONF "\"\n";
   print CONF "PDFSTREXT = \"StrVec $nPdfStreams{'cmp'}";      # filename extension for each PdfStream
   foreach $type (@cmp) {
      print CONF " $type";
   }
   print CONF "\"\n";
   print CONF "WINFN = \"";
   foreach $type (@cmp) {
      print CONF "StrVec $nwin{$type} @{$win{$type}} ";        # window coefficients files for each PdfStream
   }
   print CONF "\"\n";
   print CONF "WINDIR = $windir\n";                            # directory which stores window coefficients files
   print CONF "MAXEMITER = $maxEMiter\n";
   print CONF "EMEPSILON = $EMepsilon\n";
   if ($useGv) {
      print CONF "USEGV      = TRUE\n";
      print CONF "GVMODELMMF = $gvAllModelDir/cmp.mmf\n";
      print CONF "GVHMMLIST  = $gvAllModelDir/mlist_cmp.lst\n";
      print CONF "MAXGVITER  = $maxGViter\n";
      print CONF "GVEPSILON  = $GVepsilon\n";
      print CONF "MINEUCNORM = $minEucNorm\n";
      print CONF "STEPINIT   = $stepInit\n";
      print CONF "STEPINC    = $stepInc\n";
      print CONF "STEPDEC    = $stepDec\n";
      print CONF "HMMWEIGHT  = $hmmWeight\n";
      print CONF "GVWEIGHT   = $gvWeight\n";
      print CONF "OPTKIND    = $optKind\n";
      if ( $nosilgv && @slnt > 0 ) {
         $s = @slnt;
         print CONF "GVOFFMODEL = \"StrVec $s";
         for ( $s = 0 ; $s < @slnt ; $s++ ) {
            print CONF " $slnt[$s]";
         }
         print CONF "\"\n";
      }
      if ( $useCdGv ) {
         print CONF "CDGV       = TRUE\n";
      }
      else {
         print CONF "CDGV       = FALSE\n";
      }
   }
   close(CONF);

   shell("$HMGenS -C $synthDir/_syn.cnf -S $genLabScpFile -c $genType -H $allModelDir/cmp.mmf -N $allModelDir/dur.mmf -M $synthDir $allModelDir/mlist_cmp.lst $allModelDir/mlist_dur.lst");

   # FIXME : remove _all directory

   print_time("synthesizing waveforms ($tag)");

   # (FIXME : useMSPF should be part of gen type)

   # FIXME : allow different types of gen / postfiltering
   synth_wave( $synthDir, $corpus{'gen'}, 0, "", $synthDir );

   return $dirOut;
}

sub synth_hts_voice {
   my ( $htsVoiceFileIn, $genLabScpFile, $dirOut, $tag ) = @_;

   make_path $dirOut;

   print_time("synthesizing waveforms using hts_engine ($tag)");

   # hts_engine command line & options
   $hts_engine = "$ENGINE -m $htsVoiceFileIn ";
   if ( !$useGV ) {
      if ( $gm == 0 ) {
         $hts_engine .= "-b " . ( $pf_mcp - 1.0 ) . " ";
      }
      else {
         $hts_engine .= "-b " . $pf_lsp . " ";
      }
   }

   # generate waveform using hts_engine
   open( SCP, $genLabScpFile ) || die "Cannot open file: $!";
   while (<SCP>) {
      $lab = $_;
      chomp($lab);
      $uttId = `basename $lab .lab`;
      chomp($uttId);

      print "Synthesizing a speech waveform from $lab using hts_engine...";
      shell("$hts_engine -ow $dirOut/$uttId.wav -ot $dirOut/$uttId.trace $lab");
      print "done.\n";
   }
   close(SCP);

   return $dirOut;
}

sub convert_mmfs_to_hts_voice {
   my ( $modelDirIn, $gvModelDirIn, $tag ) = @_;
   my ( $dirOut, $htsVoiceFileOut, $useGv, $useCdGv, $set, $synthDirOut );

   print_time("converting mmfs to the HTS voice format ($tag)");

   check_model_structure( $modelDirIn, "clus_mmf" );

   $dirOut = "$modelDirIn-hts_voice";
   make_path $dirOut;
   $collateDir = "$dirOut/_collate";
   make_path $collateDir;
   $voiceDir = "$dirOut/_voice";
   make_path $voiceDir;

   $htsVoiceFileOut = "$dirOut/${dset}_$spkr.htsvoice";

   $useGv = ( $gvModelDirIn ne "" );
   $useCdGv = ( get_label_type($gvModelDirIn) ne "none" );

   # models and trees
   foreach $set ('cmp', 'dur') {
      foreach $type ( @{ $ref{$set} } ) {
         open( EDFILE, ">$collateDir/cnv_${set}_$type.hed" ) || die "Cannot open file: $!";
         print EDFILE "\nTR 2\n\n";
         print EDFILE "// load trees for $type\n";
         print EDFILE "LT \"$modelDirIn/${set}_$type.inf\"\n\n";
         print EDFILE "// convert loaded trees for hts_engine format\n";
         print EDFILE "CT \"$collateDir\"\n\n";
         print EDFILE "// convert mmf for hts_engine format\n";
         print EDFILE "CM \"$collateDir\"\n";
         close(EDFILE);

         shell("$HHEd{'trn'} -B -T 1 -H $modelDirIn/$set.mmf $collateDir/cnv_${set}_$type.hed $modelDirIn/mlist_$set.lst");
         shell("mv $collateDir/trees.$strb{$type} $voiceDir/tree-$type.inf");
         shell("mv $collateDir/pdf.$strb{$type} $voiceDir/$type.pdf");
      }
   }

   # window coefficients
   foreach $type (@cmp) {
      shell("cp $windir/$type.win* $voiceDir/");
   }

   # gv pdfs
   if ( $useGv ) {
      my $s = 1;
      foreach $type (@cmp) {    # convert hts_engine format
         open( EDFILE, ">$collateDir/cnv_cmp_${type}_gv.hed" ) || die "Cannot open file: $!";
         print EDFILE "\nTR 2\n\n";
         print EDFILE "// load trees for $type\n";
         print EDFILE "LT \"$gvModelDirIn/cmp_$type.inf\"\n\n";
         print EDFILE "// convert loaded trees for hts_engine format\n";
         print EDFILE "CT \"$collateDir\"\n\n";
         print EDFILE "// convert mmf for hts_engine format\n";
         print EDFILE "CM \"$collateDir\"\n";
         close(EDFILE);

         shell("$HHEd{'trn'} -B -T 1 -H $gvModelDirIn/cmp.mmf $collateDir/cnv_cmp_${type}_gv.hed $gvModelDirIn/mlist_cmp.lst");
         shell("mv $collateDir/trees.$s $voiceDir/tree-gv-$type.inf");
         shell("mv $collateDir/pdf.$s $voiceDir/gv-$type.pdf");
         $s++;
      }
   }

   # low-pass filter
   make_lpf($voiceDir);

   # make HTS voice
   make_hts_voice( $voiceDir, $useGv, $useCdGv, $htsVoiceFileOut );

   return ( $dirOut, $htsVoiceFileOut );
}

##################################################################################################

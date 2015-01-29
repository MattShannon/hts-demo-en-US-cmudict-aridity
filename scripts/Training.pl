#!/usr/bin/perl

# Copyright 2015 Matt Shannon
# Copyright 2001-2014 Nagoya Institute of Technology, Department of Computer Science
# Copyright 2001-2008 Tokyo Institute of Technology, Interdisciplinary Graduate School of Science and Engineering

# This file is part of hts-demo-en-US-cmudict-aridity.
# See `License` for details of license and warranty.

$| = 1;

if ( @ARGV < 1 ) {
   print "usage: Training.pl Config.pm\n";
   exit(0);
}

# load configuration variables
require( $ARGV[0] );

# model structure
foreach $set (@SET) {
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

# utterance id lists
$corpus{'trn'} = "$datdir/corpus-train.lst";
$corpus{'tst'} = "$datdir/corpus-test.lst";
$corpus{'gen'} = "$datdir/corpus-gen.lst";

# data location file
$scp{'trn'} = "$datdir/scp/train.scp";
$scp{'tst'} = "$datdir/scp/test.scp";
$scp{'trn-tst'} = "$datdir/scp/train-test.scp";
$scp{'gen'} = "$datdir/scp/gen.scp";

# model list files
$lst{'mon'} = "$datdir/lists/mono.list";
$lst{'ful'} = "$datdir/lists/full.list";
$lst{'all'} = "$datdir/lists/full_all.list";

# master label files
$mlf{'mon'} = "$datdir/labels/mono.mlf";
$mlf{'ful'} = "$datdir/labels/full.mlf";

# configuration variable files
$cfg{'trn'} = "$prjdir/configs/qst${qnum}/ver${ver}/trn.cnf";
$cfg{'tst'} = "$prjdir/configs/qst${qnum}/ver${ver}/tst.cnf";
$cfg{'nvf'} = "$prjdir/configs/qst${qnum}/ver${ver}/nvf.cnf";
$cfg{'syn'} = "$prjdir/configs/qst${qnum}/ver${ver}/syn.cnf";
$cfg{'stc'} = "$prjdir/configs/qst${qnum}/ver${ver}/stc.cnf";
foreach $type (@cmp) {
   $cfg{$type} = "$prjdir/configs/qst${qnum}/ver${ver}/${type}.cnf";
}
foreach $type (@dur) {
   $cfg{$type} = "$prjdir/configs/qst${qnum}/ver${ver}/${type}.cnf";
}

# name of proto type definition file
$prtfile{'cmp'} = "$prjdir/proto/qst${qnum}/ver${ver}/state-${nState}_stream-$nstream{'cmp'}{'total'}";
foreach $type (@cmp) {
   $prtfile{'cmp'} .= "_${type}-$vSize{'cmp'}{$type}";
}
$prtfile{'cmp'} .= ".prt";

# model files
foreach $set (@SET) {
   $modelBase     = "$prjdir/models/qst${qnum}/ver${ver}";
   $model{$set}   = "$prjdir/models/qst${qnum}/ver${ver}/${set}";
   $hinit{$set}   = "$model{$set}/HInit";
   $hrest{$set}   = "$model{$set}/HRest";
   $vfloors{$set} = "$model{$set}/vFloors";
   $avermmf{$set} = "$model{$set}/average.mmf";
   $initmmf{$set} = "$model{$set}/init.mmf";
   $reclmmf{$set} = "$model{$set}/mono-clus-clus/model.mmf";
}

# model edit files
foreach $set (@SET) {
   $hed{$set} = "$prjdir/edfiles/qst${qnum}/ver${ver}/${set}";
   $lvf{$set} = "$hed{$set}/lvf.hed";
   foreach $type ( @{ $ref{$set} } ) {
      $cnv{$type} = "$hed{$set}/cnv_$type.hed";
      $cxc{'clus'}{$type} = "$hed{$set}/cxc_clus_$type.hed";
      $cxc{'recl'}{$type} = "$hed{$set}/cxc_recl_$type.hed";
   }
}

# questions about contexts
foreach $set (@SET) {
   foreach $type ( @{ $ref{$set} } ) {
      $qs{$type}     = "$datdir/questions/questions_qst${qnum}.hed";
      $qs_utt{$type} = "$datdir/questions/questions_utt_qst${qnum}.hed";
   }
}

# decision tree files
foreach $set (@SET) {
   $trd{$set} = "${prjdir}/trees/qst${qnum}/ver${ver}/${set}";
   foreach $type ( @{ $ref{$set} } ) {
      $mdl{$type} = "-m -a $mdlf{$type}" if ( $thr{$type} eq '000' );
      $tre{'recl'}{$type} = "$modelBase/mono-clus-5-clus-5/${set}_$type.inf";
   }
}

# forced alignment files
$faldir = "$prjdir/fal/qst${qnum}/ver${ver}";
$monofal = "$modelBase/mono-fal";

# converted model & tree files for hts_engine
$voice = "$prjdir/voices/qst${qnum}/ver${ver}";
foreach $set (@SET) {
   foreach $type ( @{ $ref{$set} } ) {
      $trv{$type} = "$voice/tree-${type}.inf";
      $pdf{$type} = "$voice/${type}.pdf";
   }
}
$type       = 'lpf';
$trv{$type} = "$voice/tree-${type}.inf";
$pdf{$type} = "$voice/${type}.pdf";

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
$gvdir         = "$prjdir/gv/qst${qnum}/ver${ver}";
$gvdatdir      = "$gvdir/dat";
$gvlabdir      = "$gvdir/lab";
$scp{'gv'}     = "$gvdir/gv.scp";
$mlf{'gv'}     = "$gvdir/gv.mlf";
$prtfile{'gv'} = "$gvdir/state-1_stream-${nPdfStreams{'cmp'}}";
foreach $type (@cmp) {
   $prtfile{'gv'} .= "_${type}-$ordr{$type}";
}
$prtfile{'gv'} .= ".prt";
$avermmf{'gv'} = "$gvdir/average.mmf";
$fullmmf{'gv'} = "$gvdir/fullcontext.mmf";
$clusmmf{'gv'} = "$gvdir/clustered.mmf";
$clsammf{'gv'} = "$gvdir/clustered_all.mmf";
$tiedlst{'gv'} = "$gvdir/tiedlist";
$mku{'gv'}     = "$gvdir/mku.hed";

foreach $type (@cmp) {
   $gvcnv{$type} = "$gvdir/cnv_$type.hed";
   $gvcxc{$type} = "$gvdir/cxc_$type.hed";
   $gvmdl{$type} = "-m -a $gvmdlf{$type}" if ( $gvthr{$type} eq '000' );
   $gvtre{$type} = "$gvdir/${type}.inf";
   $gvpdf{$type} = "$voice/gv-${type}.pdf";
   $gvtrv{$type} = "$voice/tree-gv-${type}.inf";
}

# HTS Commands & Options ========================
$HCompV{'cmp'} = "$HCOMPV    -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'} -m ";
$HCompV{'gv'}  = "$HCOMPV    -A    -C $cfg{'trn'} -D -T 1 -S $scp{'gv'}  -m ";
$HList         = "$HLIST     -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'} -h -z ";
$HInit         = "$HINIT     -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'}                -m 1 -u tmvw    -w $wf ";
$HRest         = "$HREST     -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'}                -m 1 -u tmvw    -w $wf ";
$HERest{'mon'} = "$HEREST    -A    -C $cfg{'trn'} -D -T 1 -S $scp{'trn'} -I $mlf{'mon'} -m 1 -u tmvwdmv -w $wf -t $beam ";
$HERest{'ful'} = "$HEREST    -A -B -C $cfg{'trn'} -D -T 1 -S $scp{'trn'} -I $mlf{'ful'} -m 1 -u tmvwdmv -w $wf -t $beam ";
$HERest{'tst'} = "$HEREST    -A -B -C $cfg{'tst'} -D -T 1                               -m 0 -u d ";
$HERest{'gv'}  = "$HEREST    -A    -C $cfg{'trn'} -D -T 1 -S $scp{'gv'}  -I $mlf{'gv'}  -m 1 ";
$HHEd{'trn'}   = "$HHED      -A -B -C $cfg{'trn'} -D -p -i ";
$HSMMAlign     = "$HSMMALIGN -A    -C $cfg{'tst'} -D -T 1                               -t $beam -w 1.0 ";
$HMGenS        = "$HMGENS    -A -B -C $cfg{'syn'} -D -T 1                               -t $beam ";

# =============================================================
# ===================== Main Program ==========================
# =============================================================

# preparing environments
if ($MKEMV) {
   print_time("preparing environments");

   # make directories
   foreach $dir ( 'models', 'stats', 'edfiles', 'trees', 'fal', 'gv', 'mspf', 'voices', 'gen', 'proto', 'configs' ) {
      mkdir "$prjdir/$dir",                      0755;
      mkdir "$prjdir/$dir/qst${qnum}",           0755;
      mkdir "$prjdir/$dir/qst${qnum}/ver${ver}", 0755;
   }
   foreach $set (@SET) {
      mkdir "$model{$set}", 0755;
      mkdir "$hinit{$set}", 0755;
      mkdir "$hrest{$set}", 0755;
      mkdir "$hed{$set}",   0755;
      mkdir "$trd{$set}",   0755;
   }

   # make config files
   make_config();

   # make model prototype definition file
   make_proto();
}

# HCompV (computing variance floors)
if ($HCMPV) {
   print_time("computing variance floors");

   # make average model and compute variance floors
   shell("$HCompV{'cmp'} -M $model{'cmp'} -o $avermmf{'cmp'} $prtfile{'cmp'}");
   shell("head -n 1 $prtfile{'cmp'} > $initmmf{'cmp'}");
   shell("cat $vfloors{'cmp'} >> $initmmf{'cmp'}");

   make_duration_vfloor( $initdurmean, $initdurvari );
}

# HInit & HRest (initialization & reestimation)
if ($IN_RE) {
   print_time("initialization & reestimation");

   if ($daem) {
      open( LIST, $lst{'mon'} ) || die "Cannot open $!";
      while ( $phone = <LIST> ) {

         # trimming leading and following whitespace characters
         $phone =~ s/^\s+//;
         $phone =~ s/\s+$//;

         # skip a blank line
         if ( $phone eq '' ) {
            next;
         }

         print "=============== $phone ================\n";
         print "use average model instead of $phone\n";
         foreach $set (@SET) {
            open( SRC, "$avermmf{$set}" )       || die "Cannot open $!";
            open( TGT, ">$hrest{$set}/$phone" ) || die "Cannot open $!";
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
      close(LIST);
   }
   else {
      open( LIST, $lst{'mon'} ) || die "Cannot open $!";
      while ( $phone = <LIST> ) {

         # trimming leading and following whitespace characters
         $phone =~ s/^\s+//;
         $phone =~ s/\s+$//;

         # skip a blank line
         if ( $phone eq '' ) {
            next;
         }
         $lab = $mlf{'mon'};

         if ( grep( $_ eq $phone, keys %mdcp ) <= 0 ) {
            print "=============== $phone ================\n";
            shell("$HInit -H $initmmf{'cmp'} -M $hinit{'cmp'} -I $lab -l $phone -o $phone $prtfile{'cmp'}");
            shell("$HRest -H $initmmf{'cmp'} -M $hrest{'cmp'} -I $lab -l $phone -g $hrest{'dur'}/$phone $hinit{'cmp'}/$phone");
         }
      }
      close(LIST);

      open( LIST, $lst{'mon'} ) || die "Cannot open $!";
      while ( $phone = <LIST> ) {

         # trimming leading and following whitespace characters
         $phone =~ s/^\s+//;
         $phone =~ s/\s+$//;

         # skip a blank line
         if ( $phone eq '' ) {
            next;
         }

         if ( grep( $_ eq $phone, keys %mdcp ) > 0 ) {
            print "=============== $phone ================\n";
            print "use $mdcp{$phone} instead of $phone\n";
            foreach $set (@SET) {
               open( SRC, "$hrest{$set}/$mdcp{$phone}" ) || die "Cannot open $!";
               open( TGT, ">$hrest{$set}/$phone" )       || die "Cannot open $!";
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
   }
}

# HHEd (making a monophone mmf)
if ($MMMMF) {
   print_time("making a monophone mmf");

   mkdir "$modelBase/mono", 0755;

   shell("echo mono > $modelBase/mono/label_type");
   shell("cp $lst{'mon'} $modelBase/mono/mlist_cmp.lst");
   shell("cp $lst{'mon'} $modelBase/mono/mlist_dur.lst");

   foreach $set (@SET) {
      open( EDFILE, ">$lvf{$set}" ) || die "Cannot open $!";

      # load variance floor macro
      print EDFILE "// load variance flooring macro\n";
      print EDFILE "FV \"$vfloors{$set}\"\n";

      # tie stream weight macro
      foreach $type ( @{ $ref{$set} } ) {
         if ( $strw{$type} != 1.0 ) {
            print EDFILE "// tie stream weights\n";
            printf EDFILE "TI SW_all {*.state[%d-%d].weights}\n", 2, $nState + 1;
            last;
         }
      }

      close(EDFILE);

      shell("$HHEd{'trn'} -T 1 -d $hrest{$set} -w $modelBase/mono/$set.mmf $lvf{$set} $lst{'mon'}");
   }
}

# HERest (embedded reestimation (monophone))
if ($ERST0) {
   print_time("embedded reestimation (monophone)");

   if ($daem) {
      for ( $i = 1 ; $i <= $daem_nIte ; $i++ ) {
         for ( $j = 1 ; $j <= $nIte ; $j++ ) {

            # embedded reestimation
            $k = $j + ( $i - 1 ) * $nIte;
            print("\n\nIteration $k of Embedded Re-estimation\n");
            $k = ( $i / $daem_nIte )**$daem_alpha;
            shell("$HERest{'mon'} -k $k -H $modelBase/mono/cmp.mmf -N $modelBase/mono/dur.mmf -M $modelBase/mono -R $modelBase/mono $modelBase/mono/mlist_cmp.lst $modelBase/mono/mlist_dur.lst");
         }
      }
   }
   else {
      for ( $i = 1 ; $i <= $nIte ; $i++ ) {
         # embedded reestimation
         print("\n\nIteration $i of Embedded Re-estimation\n");
         shell("$HERest{'mon'} -H $modelBase/mono/cmp.mmf -N $modelBase/mono/dur.mmf -M $modelBase/mono -R $modelBase/mono $modelBase/mono/mlist_cmp.lst $modelBase/mono/mlist_dur.lst");
      }
   }
}

# HERest (computing test set log probability (monophone))
if ($LTST0) {
   eval_mono( "$modelBase/mono", $scp{'tst'}, "mono" );
}

# HSMMAlign (forced alignment (monophone))
if ($FAL0) {
   fal_on_train_corpus( "$modelBase/mono", "mono", "mono" );
}

# decision tree clustering (HHEd, HERest, HHEd)
if ($MN2FL && $ERST1 && $CXCL1) {
   decision_tree_cluster( "$modelBase/mono", "clus1" );
}

# HERest (embedded reestimation (clustered))
if ($ERST2) {
   expectation_maximization("$modelBase/mono-clus", $nIte, "clustered");
}

# decision tree clustering (HHEd, HERest, HHEd)
if ($UNTIE && $ERST3 && $CXCL2) {
   decision_tree_cluster( "$modelBase/mono-clus-5", "clus2" );
}

# HERest (embedded reestimation (re-clustered))
if ($ERST4) {
   expectation_maximization("$modelBase/mono-clus-5-clus", $nIte, "re-clustered");
}

# making global variance
if ($MCDGV) {
   print_time("making global variance");

   if ($useGV) {

      # make directories
      mkdir "$gvdatdir", 0755;
      mkdir "$gvlabdir", 0755;

      # make proto
      make_proto_gv();

      # make training data, labels, scp, list, and mlf
      make_data_gv();

      # make average model
      shell("$HCompV{'gv'} -o average.mmf -M $gvdir $prtfile{'gv'}");

      if ($cdgv) {

         # make full context depdent model
         copy_aver2full_gv();
         shell("$HERest{'gv'} -C $cfg{'nvf'} -s $gvdir/gv.stats -w 0.0 -H $fullmmf{'gv'} -M $gvdir $gvdir/gv.list");

         # context-clustering
         my $s = 1;
         shell("cp $fullmmf{'gv'} $clusmmf{'gv'}");
         foreach $type (@cmp) {
            make_edfile_state_gv( $type, $s );
            shell("$HHEd{'trn'} -T 3 -H $clusmmf{'gv'} $gvmdl{$type} -w $clusmmf{'gv'} $gvcxc{$type} $gvdir/gv.list");
            $s++;
         }

         # re-estimation
         shell("$HERest{'gv'} -H $clusmmf{'gv'} -M $gvdir $gvdir/gv.list");
      }
      else {
         copy_aver2clus_gv();
      }
   }
}

# HHEd (making unseen models (GV))
if ($MKUNG) {
   print_time("making unseen models (GV)");

   if ($useGV) {
      if ($cdgv) {
         make_edfile_mkunseen_gv();
         shell("$HHEd{'trn'} -T 1 -H $clusmmf{'gv'} -w $clsammf{'gv'} $mku{'gv'} $gvdir/gv.list");
      }
      else {
         copy_clus2clsa_gv();
      }
   }
}

# HMGenS & SPTK (training modulation spectrum-based postfilter)
if ($TMSPF and $useMSPF) {
   train_mspf( "$modelBase/mono-clus-5-clus-5", "$modelBase/mono-fal", "$datdir/labels/full", "$datdir/speech_params" );
}

# generate and synthesize (HHEd, HMGenS, SPTK / STRAIGHT)
if ($MKUN1 && $PGEN1 && $WGEN1) {
   full_synth( "$modelBase/mono-clus-5-clus-5", $lst{'all'}, $scp{'gen'}, "gv", $pgtype, "1mix" );
}

# HERest (computing test set log probability (1mix))
if ($LTST1) {
   eval_full( "$modelBase/mono-clus-5-clus-5", $lst{'all'}, $scp{'tst'}, "1mix" );
}

# HSMMAlign (forced alignment (1mix))
if ($FAL1) {
   fal_on_train_corpus( "$modelBase/mono-clus-5-clus-5", "full", "1mix" );
}

# HHEd (converting mmfs to the HTS voice format)
if ( $CONVM && !$usestraight ) {
   print_time("converting mmfs to the HTS voice format");

   $treeId = "recl";

   # models and trees
   foreach $set (@SET) {
      foreach $type ( @{ $ref{$set} } ) {
         make_edfile_convert( $type, $treeId );
         shell("$HHEd{'trn'} -T 1 -H $reclmmf{$set} $cnv{$type} $lst{'ful'}");
         shell("mv $trd{$set}/trees.$strb{$type} $trv{$type}");
         shell("mv $model{$set}/pdf.$strb{$type} $pdf{$type}");
      }
   }

   # window coefficients
   foreach $type (@cmp) {
      shell("cp $windir/${type}.win* $voice");
   }

   # gv pdfs
   if ($useGV) {
      my $s = 1;
      foreach $type (@cmp) {    # convert hts_engine format
         make_edfile_convert_gv($type);
         shell("$HHEd{'trn'} -T 1 -H $clusmmf{'gv'} $gvcnv{$type} $gvdir/gv.list");
         shell("mv $gvdir/trees.$s $gvtrv{$type}");
         shell("mv $gvdir/pdf.$s $gvpdf{$type}");
         $s++;
      }
   }

   # low-pass filter
   make_lpf();

   # make HTS voice
   make_htsvoice( "$voice", "${dset}_${spkr}" );
}

# hts_engine (synthesizing waveforms using hts_engine)
if ( $ENGIN && !$usestraight ) {
   print_time("synthesizing waveforms using hts_engine");

   $dir = "${prjdir}/gen/qst${qnum}/ver${ver}/hts_engine";
   mkdir ${dir}, 0755;

   # hts_engine command line & options
   $hts_engine = "$ENGINE -m ${voice}/${dset}_${spkr}.htsvoice ";
   if ( !$useGV ) {
      if ( $gm == 0 ) {
         $hts_engine .= "-b " . ( $pf_mcp - 1.0 ) . " ";
      }
      else {
         $hts_engine .= "-b " . $pf_lsp . " ";
      }
   }

   # generate waveform using hts_engine
   open( SCP, "$scp{'gen'}" ) || die "Cannot open $!";
   while (<SCP>) {
      $lab = $_;
      chomp($lab);
      $base = `basename $lab .lab`;
      chomp($base);

      print "Synthesizing a speech waveform from $lab using hts_engine...";
      shell("$hts_engine -or ${dir}/${base}.raw -ow ${dir}/${base}.wav -ot ${dir}/${base}.trace $lab");
      print "done.\n";
   }
   close(SCP);
}

# HERest (semi-tied covariance matrices)
if ($SEMIT) {
   estimate_semi_tied_cov( "$modelBase/mono-clus-5-clus-5", "stc" );
}

# generate and synthesize (HHEd, HMGenS, SPTK / STRAIGHT)
if ($MKUNS && $PGENS && $WGENS) {
   full_synth( "$modelBase/mono-clus-5-clus-5-stc", $lst{'all'}, $scp{'gen'}, "gv", 0, "stc" );
}

# HERest (computing test set log probability (stc))
if ($LTSTS) {
   eval_full( "$modelBase/mono-clus-5-clus-5-stc", $lst{'all'}, $scp{'tst'}, "stc" );
}

# HSMMAlign (forced alignment (stc))
if ($FALS) {
   fal_on_train_corpus( "$modelBase/mono-clus-5-clus-5-stc", "full", "stc" );
}

# HHED (increasing the number of mixture components (1mix -> 2mix))
if ($UPMIX) {
   upmix2( "$modelBase/mono-clus-5-clus-5", "1mix -> 2mix" );
}

# HERest (embedded reestimation (2mix))
if ($ERST5) {
   expectation_maximization("$modelBase/mono-clus-5-clus-5-mix+1", $nIte, "2mix");
}

# generate and synthesize (HHEd, HMGenS, SPTK / STRAIGHT)
if ($MKUN2 && $PGEN2 && $WGEN2) {
   full_synth( "$modelBase/mono-clus-5-clus-5-mix+1-5", $lst{'all'}, $scp{'gen'}, "gv", 0, "2mix" );
}

# HERest (computing test set log probability (2mix))
if ($LTST2) {
   eval_full( "$modelBase/mono-clus-5-clus-5-mix+1-5", $lst{'all'}, $scp{'tst'}, "2mix" );
}

# HSMMAlign (forced alignment (2mix))
if ($FAL2) {
   fal_on_train_corpus( "$modelBase/mono-clus-5-clus-5-mix+1-5", "full", "2mix" );
}

# sub routines ============================
sub shell($) {
   my ($command) = @_;
   my ($exit);

   $exit = system($command);

   if ( $exit / 256 != 0 ) {
      die "Error in $command\n";
   }
}

sub print_time ($) {
   my ($message) = @_;
   my ($ruler);

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

# sub routine for generating proto-type model
sub make_proto {
   my ( $i, $j, $k, $s );

   # output prototype definition
   # open proto type definition file
   open( PROTO, ">$prtfile{'cmp'}" ) || die "Cannot open $!";

   # output header
   # output vector size & feature type
   print PROTO "~o <VecSize> $vSize{'cmp'}{'total'} <USER> <DIAGC>";

   # output information about multi-space probability distribution (MSD)
   print PROTO "<MSDInfo> $nstream{'cmp'}{'total'} ";
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         print PROTO " $msdi{$type} ";
      }
   }

   # output information about stream
   print PROTO "<StreamInfo> $nstream{'cmp'}{'total'}";
   foreach $type (@cmp) {
      for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
         printf PROTO " %d", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
      }
   }
   print PROTO "\n";

   # output HMMs
   print PROTO "<BeginHMM>\n";
   printf PROTO "  <NumStates> %d\n", $nState + 2;

   # output HMM states
   for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {

      # output state information
      print PROTO "  <State> $i\n";

      # output stream weight
      print PROTO "  <SWeights> $nstream{'cmp'}{'total'}";
      foreach $type (@cmp) {
         for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
            print PROTO " $strw{$type}";
         }
      }
      print PROTO "\n";

      # output stream information
      foreach $type (@cmp) {
         for ( $s = $strb{$type} ; $s <= $stre{$type} ; $s++ ) {
            print PROTO "  <Stream> $s\n";
            if ( $msdi{$type} == 0 ) {    # non-MSD stream
                                          # output mean vector
               printf PROTO "    <Mean> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
               for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
                  print PROTO "      " if ( $k % 10 == 1 );
                  print PROTO "0.0 ";
                  print PROTO "\n" if ( $k % 10 == 0 );
               }
               print PROTO "\n" if ( $k % 10 != 1 );

               # output covariance matrix (diag)
               printf PROTO "    <Variance> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
               for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
                  print PROTO "      " if ( $k % 10 == 1 );
                  print PROTO "1.0 ";
                  print PROTO "\n" if ( $k % 10 == 0 );
               }
               print PROTO "\n" if ( $k % 10 != 1 );
            }
            else {    # MSD stream
                      # output MSD
               print PROTO "  <NumMixes> 2\n";

               # output 1st space (non 0-dimensional space)
               # output space weights
               print PROTO "  <Mixture> 1 0.5000\n";

               # output mean vector
               printf PROTO "    <Mean> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
               for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
                  print PROTO "      " if ( $k % 10 == 1 );
                  print PROTO "0.0 ";
                  print PROTO "\n" if ( $k % 10 == 0 );
               }
               print PROTO "\n" if ( $k % 10 != 1 );

               # output covariance matrix (diag)
               printf PROTO "    <Variance> %d\n", $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type};
               for ( $k = 1 ; $k <= $vSize{'cmp'}{$type} / $nstream{'cmp'}{$type} ; $k++ ) {
                  print PROTO "      " if ( $k % 10 == 1 );
                  print PROTO "1.0 ";
                  print PROTO "\n" if ( $k % 10 == 0 );
               }
               print PROTO "\n" if ( $k % 10 != 1 );

               # output 2nd space (0-dimensional space)
               print PROTO "  <Mixture> 2 0.5000\n";
               print PROTO "    <Mean> 0\n";
               print PROTO "    <Variance> 0\n";
            }
         }
      }
   }

   # output state transition matrix
   printf PROTO "  <TransP> %d\n", $nState + 2;
   print PROTO "    ";
   for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
      print PROTO "1.000e+0 " if ( $j == 2 );
      print PROTO "0.000e+0 " if ( $j != 2 );
   }
   print PROTO "\n";
   print PROTO "    ";
   for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {
      for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
         print PROTO "6.000e-1 " if ( $i == $j );
         print PROTO "4.000e-1 " if ( $i == $j - 1 );
         print PROTO "0.000e+0 " if ( $i != $j && $i != $j - 1 );
      }
      print PROTO "\n";
      print PROTO "    ";
   }
   for ( $j = 1 ; $j <= $nState + 2 ; $j++ ) {
      print PROTO "0.000e+0 ";
   }
   print PROTO "\n";

   # output footer
   print PROTO "<EndHMM>\n";

   close(PROTO);
}

sub make_duration_vfloor {
   my ( $dm, $dv ) = @_;
   my ( $i, $j );

   # output variance flooring macro for duration model
   open( VF, ">$vfloors{'dur'}" ) || die "Cannot open $!";
   for ( $i = 1 ; $i <= $nState ; $i++ ) {
      print VF "~v varFloor$i\n";
      print VF "<Variance> 1\n";
      $j = $dv * $vflr{'dur'};
      print VF " $j\n";
   }
   close(VF);

   # output average model for duration model
   open( MMF, ">$avermmf{'dur'}" ) || die "Cannot open $!";
   print MMF "~o\n";
   print MMF "<STREAMINFO> $nState";
   for ( $i = 1 ; $i <= $nState ; $i++ ) {
      print MMF " 1";
   }
   print MMF "\n";
   print MMF "<VECSIZE> ${nState}<NULLD><USER><DIAGC>\n";
   print MMF "~h \"$avermmf{'dur'}\"\n";
   print MMF "<BEGINHMM>\n";
   print MMF "<NUMSTATES> 3\n";
   print MMF "<STATE> 2\n";
   for ( $i = 1 ; $i <= $nState ; $i++ ) {
      print MMF "<STREAM> $i\n";
      print MMF "<MEAN> 1\n";
      print MMF " $dm\n";
      print MMF "<VARIANCE> 1\n";
      print MMF " $dv\n";
   }
   print MMF "<TRANSP> 3\n";
   print MMF " 0.0 1.0 0.0\n";
   print MMF " 0.0 0.0 1.0\n";
   print MMF " 0.0 0.0 0.0\n";
   print MMF "<ENDHMM>\n";
   close(MMF);
}

# sub routine for generating proto-type model for GV
sub make_proto_gv {
   my ( $s, $type, $k );

   open( PROTO, "> $prtfile{'gv'}" ) || die "Cannot open $!";
   $s = 0;
   foreach $type (@cmp) {
      $s += $ordr{$type};
   }
   print PROTO "~o <VecSize> $s <USER> <DIAGC>\n";
   print PROTO "<MSDInfo> $nPdfStreams{'cmp'} ";
   foreach $type (@cmp) {
      print PROTO "0 ";
   }
   print PROTO "\n";
   print PROTO "<StreamInfo> $nPdfStreams{'cmp'} ";
   foreach $type (@cmp) {
      print PROTO "$ordr{$type} ";
   }
   print PROTO "\n";
   print PROTO "<BeginHMM>\n";
   print PROTO "  <NumStates> 3\n";
   print PROTO "  <State> 2\n";
   $s = 1;
   foreach $type (@cmp) {
      print PROTO "  <Stream> $s\n";
      print PROTO "    <Mean> $ordr{$type}\n";
      for ( $k = 1 ; $k <= $ordr{$type} ; $k++ ) {
         print PROTO "      " if ( $k % 10 == 1 );
         print PROTO "0.0 ";
         print PROTO "\n" if ( $k % 10 == 0 );
      }
      print PROTO "\n" if ( $k % 10 != 1 );
      print PROTO "    <Variance> $ordr{$type}\n";
      for ( $k = 1 ; $k <= $ordr{$type} ; $k++ ) {
         print PROTO "      " if ( $k % 10 == 1 );
         print PROTO "1.0 ";
         print PROTO "\n" if ( $k % 10 == 0 );
      }
      print PROTO "\n" if ( $k % 10 != 1 );
      $s++;
   }
   print PROTO "  <TransP> 3\n";
   print PROTO "    0.000e+0 1.000e+0 0.000e+0 \n";
   print PROTO "    0.000e+0 0.000e+0 1.000e+0 \n";
   print PROTO "    0.000e+0 0.000e+0 0.000e+0 \n";
   print PROTO "<EndHMM>\n";
   close(PROTO);
}

# sub routine for making training data, labels, scp, list, and mlf for GV
sub make_data_gv {
   my ( $type, $cmp, $base, $str, @arr, $start, $end, $find, $i, $j );

   shell("rm -f $scp{'gv'}");
   shell("touch $scp{'gv'}");
   open( SCP, $scp{'trn'} ) || die "Cannot open $!";
   if ($cdgv) {
      open( LST, "> $gvdir/tmp.list" );
   }
   while (<SCP>) {
      $cmp = $_;
      chomp($cmp);
      $base = `basename $cmp .cmp`;
      chomp($base);
      print "Making data, labels, and scp from $base.lab for GV...";
      shell("rm -f $gvdatdir/tmp.cmp");
      shell("touch $gvdatdir/tmp.cmp");
      $i = 0;

      foreach $type (@cmp) {
         if ( $nosilgv && @slnt > 0 ) {
            shell("rm -f $gvdatdir/tmp.$type");
            shell("touch $gvdatdir/tmp.$type");
            open( F, "$monofal/$base.lab" ) || die "Cannot open $!";
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
                  shell("$BCUT -s $start -e $end -l $ordr{$type} < $datdir/speech_params/$base.$type >> $gvdatdir/tmp.$type");
               }
            }
            close(F);
         }
         else {
            shell("cp $datdir/speech_params/$base.$type $gvdatdir/tmp.$type");
         }
         if ( $msdi{$type} == 0 ) {
            shell("cat      $gvdatdir/tmp.$type                              | $VSTAT -d -l $ordr{$type} -o 2 >> $gvdatdir/tmp.cmp");
         }
         else {
            shell("$X2X +fa $gvdatdir/tmp.$type | grep -v '1e+10' | $X2X +af | $VSTAT -d -l $ordr{$type} -o 2 >> $gvdatdir/tmp.cmp");
         }
         system("rm -f $gvdatdir/tmp.$type");
         $i += 4 * $ordr{$type};
      }
      shell("$PERL $datdir/scripts/addhtkheader.pl $sr $fs $i 9 $gvdatdir/tmp.cmp > $gvdatdir/$base.cmp");
      $i = `$NAN $gvdatdir/$base.cmp`;
      chomp($i);
      if ( length($i) > 0 ) {
         shell("rm -f $gvdatdir/$base.cmp");
      }
      else {
         shell("echo $gvdatdir/$base.cmp >> $scp{'gv'}");
         if ($cdgv) {
            open( LAB, "$datdir/labels/full/$base.lab" ) || die "Cannot open $!";
            $str = <LAB>;
            close(LAB);
            chomp($str);
            while ( index( $str, " " ) >= 0 || index( $str, "\t" ) >= 0 ) { substr( $str, 0, 1 ) = ""; }
            open( LAB, "> $gvlabdir/$base.lab" ) || die "Cannot open $!";
            print LAB "$str\n";
            close(LAB);
            print LST "$str\n";
         }
      }
      system("rm -f $gvdatdir/tmp.cmp");
      print "done\n";
   }
   if ($cdgv) {
      close(LST);
      system("sort -u $gvdir/tmp.list > $gvdir/gv.list");
      system("rm -f $gvdir/tmp.list");
   }
   else {
      system("echo gv > $gvdir/gv.list");
   }
   close(SCP);

   # make mlf
   open( MLF, "> $mlf{'gv'}" ) || die "Cannot open $!";
   print MLF "#!MLF!#\n";
   print MLF "\"*/*.lab\" -> \"$gvlabdir\"\n";
   close(MLF);
}

# sub routine to copy average.mmf to full.mmf for GV
sub copy_aver2full_gv {
   my ( $find, $head, $tail, $str );

   $find = 0;
   $head = "";
   $tail = "";
   open( MMF, "$avermmf{'gv'}" ) || die "Cannot open $!";
   while ( $str = <MMF> ) {
      if ( index( $str, "~h" ) >= 0 ) {
         $find = 1;
      }
      elsif ( $find == 0 ) {
         $head .= $str;
      }
      else {
         $tail .= $str;
      }
   }
   close(MMF);
   $head .= `cat $gvdir/vFloors`;
   open( LST, "$gvdir/gv.list" )   || die "Cannot open $!";
   open( MMF, "> $fullmmf{'gv'}" ) || die "Cannot open $!";
   print MMF "$head";
   while ( $str = <LST> ) {
      chomp($str);
      print MMF "~h \"$str\"\n";
      print MMF "$tail";
   }
   close(MMF);
   close(LST);
}

sub copy_aver2clus_gv {
   my ( $find, $head, $mid, $tail, $str, $tmp, $s, @pdfs );

   # initialize
   $find = 0;
   $head = "";
   $mid  = "";
   $tail = "";
   $s    = 0;
   @pdfs = ();
   foreach $type (@cmp) {
      push( @pdfs, "" );
   }

   # load
   open( MMF, "$avermmf{'gv'}" ) || die "Cannot open $!";
   while ( $str = <MMF> ) {
      if ( index( $str, "~h" ) >= 0 ) {
         $head .= `cat $gvdir/vFloors`;
         last;
      }
      else {
         $head .= $str;
      }
   }
   while ( $str = <MMF> ) {
      if ( index( $str, "<STREAM>" ) >= 0 ) {
         last;
      }
      else {
         $mid .= $str;
      }
   }
   while ( $str = <MMF> ) {
      if ( index( $str, "<TRANSP>" ) >= 0 ) {
         $tail .= $str;
         last;
      }
      elsif ( index( $str, "<STREAM>" ) >= 0 ) {
         $s++;
      }
      else {
         $pdfs[$s] .= $str;
      }
   }
   while ( $str = <MMF> ) {
      $tail .= $str;
   }
   close(MMF);

   # save
   open( MMF, "> $clusmmf{'gv'}" ) || die "Cannot open $!";
   print MMF "$head";
   $s = 1;
   foreach $type (@cmp) {
      print MMF "~p \"gv_${type}_1\"\n";
      print MMF "<STREAM> $s\n";
      print MMF "$pdfs[$s-1]";
      $s++;
   }
   print MMF "~h \"gv\"\n";
   print MMF "$mid";
   $s = 1;
   foreach $type (@cmp) {
      print MMF "<STREAM> $s\n";
      print MMF "~p \"gv_${type}_1\"\n";
      $s++;
   }
   print MMF "$tail";
   close(MMF);
   close(LST);
}

sub copy_clus2clsa_gv {
   shell("cp $clusmmf{'gv'} $clsammf{'gv'}");
   shell("cp $gvdir/gv.list $tiedlst{'gv'}");
}

sub make_stc_config($$) {
   my ( $stcBaseFileIn, $cfgFileOut ) = @_;

   # config file for STC
   open( CONF, ">$cfgFileOut" ) || die "Cannot open $!";
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
sub make_stc_base($) {
   my ($stcBaseFileOut) = @_;
   my ( $type, $s, $class );

   # output baseclass definition
   # open baseclass definition file
   open( BASE, ">$stcBaseFileOut" ) || die "Cannot open $!";

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
   my ( $s, $type, @boolstring, $b, $bSize );
   $boolstring[0] = 'FALSE';
   $boolstring[1] = 'TRUE';

   # config file for model training
   open( CONF, ">$cfg{'trn'}" ) || die "Cannot open $!";
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
   open( CONF, ">$cfg{'tst'}" ) || die "Cannot open $!";
   print CONF "NATURALREADORDER = T\n";
   print CONF "NATURALWRITEORDER = T\n";
   print CONF "MAXSTDDEVCOEF = $maxdev\n";
   print CONF "MINDUR = $mindur\n";
   close(CONF);

   # config file for model training (without variance flooring)
   open( CONF, ">$cfg{'nvf'}" ) || die "Cannot open $!";
   print CONF "APPLYVFLOOR = F\n";
   print CONF "DURVARFLOORPERCENTILE = 0.0\n";
   print CONF "APPLYDURVARFLOOR = F\n";
   close(CONF);

   # config file for model tying
   foreach $type (@cmp) {
      open( CONF, ">$cfg{$type}" ) || die "Cannot open $!";
      print CONF "MINLEAFOCC = $mocc{$type}\n";
      close(CONF);
   }
   foreach $type (@dur) {
      open( CONF, ">$cfg{$type}" ) || die "Cannot open $!";
      print CONF "MINLEAFOCC = $mocc{$type}\n";
      close(CONF);
   }

   # config file for parameter generation
   open( CONF, ">$cfg{'syn'}" ) || die "Cannot open $!";
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
   print CONF "USEGV      = $boolstring[$useGV]\n";
   print CONF "GVMODELMMF = $clsammf{'gv'}\n";
   print CONF "GVHMMLIST  = $tiedlst{'gv'}\n";
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
   print CONF "CDGV       = $boolstring[$cdgv]\n";

   close(CONF);
}

# sub routine for generating .hed files for decision-tree clustering
sub make_edfile_state($$$$) {
   my ( $type, $statsFileIn, $edFile, $treeFileOut ) = @_;
   my ( @lines, $i, @nstate );

   $nstate{'cmp'} = $nState;
   $nstate{'dur'} = 1;

   open( QSFILE, "$qs{$type}" ) || die "Cannot open $!";
   @lines = <QSFILE>;
   close(QSFILE);

   open( EDFILE, ">$edFile" ) || die "Cannot open $!";
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
sub make_edfile_state_gv($$) {
   my ( $type, $s ) = @_;
   my (@lines);

   open( QSFILE, "$qs_utt{$type}" ) || die "Cannot open $!";
   @lines = <QSFILE>;
   close(QSFILE);

   open( EDFILE, ">$gvcxc{$type}" ) || die "Cannot open $!";
   if ($cdgv) {
      print EDFILE "// load stats file\n";
      print EDFILE "RO $gvgam{$type} \"$gvdir/gv.stats\"\n";
      print EDFILE "TR 0\n\n";
      print EDFILE "// questions for decision tree-based context clustering\n";
      print EDFILE @lines;
      print EDFILE "TR 3\n\n";
      print EDFILE "// construct decision trees\n";
      print EDFILE "TB $gvthr{$type} gv_${type}_ {*.state[2].stream[$s]}\n";
      print EDFILE "\nTR 1\n\n";
      print EDFILE "// output constructed trees\n";
      print EDFILE "ST \"$gvtre{$type}\"\n";
   }
   else {
      open( TREE, ">$gvtre{$type}" ) || die "Cannot open $!";
      print TREE " {*}[2].stream[$s]\n   \"gv_${type}_1\"\n";
      close(TREE);
      print EDFILE "// construct tying structure\n";
      print EDFILE "TI gv_${type}_1 {*.state[2].stream[$s]}\n";
   }
   close(EDFILE);
}

# sub routine for untying structures
sub make_edfile_untie($$) {
   my ( $set, $edFile ) = @_;
   my ( $type, $i, @nstate );

   $nstate{'cmp'} = $nState;
   $nstate{'dur'} = 1;

   open( EDFILE, ">$edFile" ) || die "Cannot open $!";

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
sub make_edfile_upmix($$) {
   my ( $set, $edFile ) = @_;
   my ( $type, $i, @nstate );

   $nstate{'cmp'} = $nState;
   $nstate{'dur'} = 1;

   open( EDFILE, ">$edFile" ) || die "Cannot open $!";

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
sub convstats($$) {
   my ( $cmpStatsFileIn, $durStatsFileOut ) = @_;

   open( IN,  "$cmpStatsFileIn" )  || die "Cannot open $!";
   open( OUT, ">$durStatsFileOut" ) || die "Cannot open $!";
   while (<IN>) {
      @LINE = split(' ');
      printf OUT ( "%4d %14s %4d %4d\n", $LINE[0], $LINE[1], $LINE[2], $LINE[2] );
   }
   close(IN);
   close(OUT);
}

# sub routine for generating .hed files for mmf -> hts_engine conversion
sub make_edfile_convert($$) {
   my ( $type, $treeId ) = @_;

   open( EDFILE, ">$cnv{$type}" ) || die "Cannot open $!";
   print EDFILE "\nTR 2\n\n";
   print EDFILE "// load trees for $type\n";
   print EDFILE "LT \"$tre{$treeId}{$type}\"\n\n";

   print EDFILE "// convert loaded trees for hts_engine format\n";
   print EDFILE "CT \"$trd{$t2s{$type}}\"\n\n";

   print EDFILE "// convert mmf for hts_engine format\n";
   print EDFILE "CM \"$model{$t2s{$type}}\"\n";

   close(EDFILE);
}

# sub routine for generating .hed files for GV mmf -> hts_engine conversion
sub make_edfile_convert_gv($) {
   my ($type) = @_;

   open( EDFILE, ">$gvcnv{$type}" ) || die "Cannot open $!";
   print EDFILE "\nTR 2\n\n";
   print EDFILE "// load trees for $type\n";
   print EDFILE "LT \"$gvdir/$type.inf\"\n\n";

   print EDFILE "// convert loaded trees for hts_engine format\n";
   print EDFILE "CT \"$gvdir\"\n\n";

   print EDFILE "// convert mmf for hts_engine format\n";
   print EDFILE "CM \"$gvdir\"\n";

   close(EDFILE);
}

# sub routine for generating .hed files for making unseen models
sub make_edfile_mkunseen($$$$$) {
   my ( $modelDirIn, $genMListFile, $set, $edFile, $tiedMListFileOut ) = @_;
   my ($type);

   open( EDFILE, ">$edFile" ) || die "Cannot open $!";
   print EDFILE "\nTR 2\n\n";
   foreach $type ( @{ $ref{$set} } ) {
      print EDFILE "// load trees for $type\n";
      print EDFILE "LT \"$modelDirIn/${set}_$type.inf\"\n\n";
   }

   print EDFILE "// make unseen model\n";
   print EDFILE "AU \"$genMListFile\"\n\n";
   print EDFILE "// make model compact\n";
   print EDFILE "CO \"$tiedMListFileOut\"\n\n";

   close(EDFILE);
}

# sub routine for generating .hed files for making unseen models for GV
sub make_edfile_mkunseen_gv {
   my ($type);

   open( EDFILE, ">$mku{'gv'}" ) || die "Cannot open $!";
   print EDFILE "\nTR 2\n\n";
   foreach $type (@cmp) {
      print EDFILE "// load trees for $type\n";
      print EDFILE "LT \"$gvtre{$type}\"\n\n";
   }

   print EDFILE "// make unseen model\n";
   print EDFILE "AU \"$lst{'all'}\"\n\n";
   print EDFILE "// make model compact\n";
   print EDFILE "CO \"$tiedlst{'gv'}\"\n\n";

   close(EDFILE);
}

# sub routine for generating low pass filter of hts_engine API
sub make_lpf {
   my ( $lfil, @coef, $coefSize, $i, $j );

   $lfil     = `$PERL $datdir/scripts/makefilter.pl $sr 0`;
   @coef     = split( '\s', $lfil );
   $coefSize = @coef;

   shell("rm -f $pdf{'lpf'}");
   shell("touch $pdf{'lpf'}");
   for ( $i = 0 ; $i < $nState ; $i++ ) {
      shell("echo 1 | $X2X +ai >> $pdf{'lpf'}");
   }
   for ( $i = 0 ; $i < $nState ; $i++ ) {
      for ( $j = 0 ; $j < $coefSize ; $j++ ) {
         shell("echo $coef[$j] | $X2X +af >> $pdf{'lpf'}");
      }
      for ( $j = 0 ; $j < $coefSize ; $j++ ) {
         shell("echo 0.0 | $X2X +af >> $pdf{'lpf'}");
      }
   }

   open( INF, "> $trv{'lpf'}" );
   for ( $i = 2 ; $i <= $nState + 1 ; $i++ ) {
      print INF "{*}[${i}]\n";
      print INF "   \"lpf_s${i}_1\"\n";
   }
   close(INF);

   open( WIN, "> $voice/lpf.win1" );
   print WIN "1 1.0\n";
   close(WIN);
}

# sub routine for generating HTS voice for hts_engine API
sub make_htsvoice($$) {
   my ( $voicedir, $voicename ) = @_;
   my ( $i, $type, $tmp, @coef, $coefSize, $file_index, $s, $e );

   open( HTSVOICE, "> ${voicedir}/${voicename}.htsvoice" );

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
      $tmp = get_stream_name( $cmp[$i] );
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
      $tmp = get_stream_name($type);
      print HTSVOICE "VECTOR_LENGTH[${tmp}]:${ordr{$type}}\n";
   }
   $type     = "lpf";
   $tmp      = get_stream_name($type);
   @coef     = split( '\s', `$PERL $datdir/scripts/makefilter.pl $sr 0` );
   $coefSize = @coef;
   print HTSVOICE "VECTOR_LENGTH[${tmp}]:${coefSize}\n";
   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      print HTSVOICE "IS_MSD[${tmp}]:${msdi{$type}}\n";
   }
   $type = "lpf";
   $tmp  = get_stream_name($type);
   print HTSVOICE "IS_MSD[${tmp}]:0\n";
   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      print HTSVOICE "NUM_WINDOWS[${tmp}]:${nwin{$type}}\n";
   }
   $type = "lpf";
   $tmp  = get_stream_name($type);
   print HTSVOICE "NUM_WINDOWS[${tmp}]:1\n";
   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      if ($useGV) {
         print HTSVOICE "USE_GV[${tmp}]:1\n";
      }
      else {
         print HTSVOICE "USE_GV[${tmp}]:0\n";
      }
   }
   $type = "lpf";
   $tmp  = get_stream_name($type);
   print HTSVOICE "USE_GV[${tmp}]:0\n";
   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
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
   $tmp  = get_stream_name($type);
   print HTSVOICE "OPTION[${tmp}]:\n";

   # position
   $file_index = 0;
   print HTSVOICE "[POSITION]\n";
   $file_size = get_file_size("${voicedir}/dur.pdf");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "DURATION_PDF:${s}-${e}\n";
   $file_index += $file_size;
   $file_size = get_file_size("${voicedir}/tree-dur.inf");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "DURATION_TREE:${s}-${e}\n";
   $file_index += $file_size;

   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      print HTSVOICE "STREAM_WIN[${tmp}]:";
      for ( $i = 0 ; $i < $nwin{$type} ; $i++ ) {
         $file_size = get_file_size("${voicedir}/$win{$type}[$i]");
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
   $tmp  = get_stream_name($type);
   print HTSVOICE "STREAM_WIN[${tmp}]:";
   $file_size = get_file_size("$voicedir/$win{$type}[0]");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "${s}-${e}";
   $file_index += $file_size;
   print HTSVOICE "\n";

   foreach $type (@cmp) {
      $tmp       = get_stream_name($type);
      $file_size = get_file_size("${voicedir}/${type}.pdf");
      $s         = $file_index;
      $e         = $file_index + $file_size - 1;
      print HTSVOICE "STREAM_PDF[$tmp]:${s}-${e}\n";
      $file_index += $file_size;
   }
   $type      = "lpf";
   $tmp       = get_stream_name($type);
   $file_size = get_file_size("${voicedir}/${type}.pdf");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "STREAM_PDF[$tmp]:${s}-${e}\n";
   $file_index += $file_size;

   foreach $type (@cmp) {
      $tmp       = get_stream_name($type);
      $file_size = get_file_size("${voicedir}/tree-${type}.inf");
      $s         = $file_index;
      $e         = $file_index + $file_size - 1;
      print HTSVOICE "STREAM_TREE[$tmp]:${s}-${e}\n";
      $file_index += $file_size;
   }
   $type      = "lpf";
   $tmp       = get_stream_name($type);
   $file_size = get_file_size("${voicedir}/tree-${type}.inf");
   $s         = $file_index;
   $e         = $file_index + $file_size - 1;
   print HTSVOICE "STREAM_TREE[$tmp]:${s}-${e}\n";
   $file_index += $file_size;

   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      if ($useGV) {
         $file_size = get_file_size("${voicedir}/gv-${type}.pdf");
         $s         = $file_index;
         $e         = $file_index + $file_size - 1;
         print HTSVOICE "GV_PDF[$tmp]:${s}-${e}\n";
         $file_index += $file_size;
      }
   }
   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      if ( $useGV && $cdgv ) {
         $file_size = get_file_size("${voicedir}/tree-gv-${type}.inf");
         $s         = $file_index;
         $e         = $file_index + $file_size - 1;
         print HTSVOICE "GV_TREE[$tmp]:${s}-${e}\n";
         $file_index += $file_size;
      }
   }

   # data information
   print HTSVOICE "[DATA]\n";
   open( I, "${voicedir}/dur.pdf" ) || die "Cannot open $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;
   open( I, "${voicedir}/tree-dur.inf" ) || die "Cannot open $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;

   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      for ( $i = 0 ; $i < $nwin{$type} ; $i++ ) {
         open( I, "${voicedir}/$win{$type}[$i]" ) || die "Cannot open $!";
         @STAT = stat(I);
         read( I, $DATA, $STAT[7] );
         close(I);
         print HTSVOICE $DATA;
      }
   }
   $type = "lpf";
   $tmp  = get_stream_name($type);
   open( I, "${voicedir}/$win{$type}[0]" ) || die "Cannot open $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;

   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      open( I, "${voicedir}/${type}.pdf" ) || die "Cannot open $!";
      @STAT = stat(I);
      read( I, $DATA, $STAT[7] );
      close(I);
      print HTSVOICE $DATA;
   }
   $type = "lpf";
   $tmp  = get_stream_name($type);
   open( I, "${voicedir}/${type}.pdf" ) || die "Cannot open $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;

   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      open( I, "${voicedir}/tree-${type}.inf" ) || die "Cannot open $!";
      @STAT = stat(I);
      read( I, $DATA, $STAT[7] );
      close(I);
      print HTSVOICE $DATA;
   }
   $type = "lpf";
   $tmp  = get_stream_name($type);
   open( I, "${voicedir}/tree-${type}.inf" ) || die "Cannot open $!";
   @STAT = stat(I);
   read( I, $DATA, $STAT[7] );
   close(I);
   print HTSVOICE $DATA;

   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      if ($useGV) {
         open( I, "${voicedir}/gv-${type}.pdf" ) || die "Cannot open $!";
         @STAT = stat(I);
         read( I, $DATA, $STAT[7] );
         close(I);
         print HTSVOICE $DATA;
      }
   }
   foreach $type (@cmp) {
      $tmp = get_stream_name($type);
      if ( $useGV && $cdgv ) {
         open( I, "${voicedir}/tree-gv-${type}.inf" ) || die "Cannot open $!";
         @STAT = stat(I);
         read( I, $DATA, $STAT[7] );
         close(I);
         print HTSVOICE $DATA;
      }
   }
   close(HTSVOICE);
}

# sub routine for getting stream name for HTS voice
sub get_stream_name($) {
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
sub get_file_size($) {
   my ($file) = @_;
   my ($file_size);

   $file_size = `$WC -c < $file`;
   chomp($file_size);

   return $file_size;
}

# sub routine for formant emphasis in mel-cepstral domain
sub postfiltering_mcp($$) {
   my ( $base, $gendir ) = @_;
   my ( $i, $line );

   # output postfiltering weight coefficient
   $line = "echo 1 1 ";
   for ( $i = 2 ; $i < $ordr{'mgc'} ; $i++ ) {
      $line .= "$pf_mcp ";
   }
   $line .= "| $X2X +af > $gendir/weight";
   shell($line);

   # calculate auto-correlation of original mcep
   $line = "$FREQT -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw -M $co -A 0 < $gendir/${base}.mgc | ";
   $line .= "$C2ACR -m $co -M 0 -l $fl > $gendir/${base}.r0";
   shell($line);

   # calculate auto-correlation of postfiltered mcep
   $line = "$VOPR -m -n " . ( $ordr{'mgc'} - 1 ) . " < $gendir/${base}.mgc $gendir/weight | ";
   $line .= "$FREQT -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw -M $co -A 0 | ";
   $line .= "$C2ACR -m $co -M 0 -l $fl > $gendir/${base}.p_r0";
   shell($line);

   # calculate MLSA coefficients from postfiltered mcep
   $line = "$VOPR -m -n " . ( $ordr{'mgc'} - 1 ) . " < $gendir/${base}.mgc $gendir/weight | ";
   $line .= "$MC2B -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw | ";
   $line .= "$BCP -n " .  ( $ordr{'mgc'} - 1 ) . " -s 0 -e 0 > $gendir/${base}.b0";
   shell($line);

   # calculate 0.5 * log(acr_orig/acr_post)) and add it to 0th MLSA coefficient
   $line = "$VOPR -d < $gendir/${base}.r0 $gendir/${base}.p_r0 | ";
   $line .= "$SOPR -LN -d 2 | ";
   $line .= "$VOPR -a $gendir/${base}.b0 > $gendir/${base}.p_b0";
   shell($line);

   # generate postfiltered mcep
   $line = "$VOPR -m -n " . ( $ordr{'mgc'} - 1 ) . " < $gendir/${base}.mgc $gendir/weight | ";
   $line .= "$MC2B -m " .  ( $ordr{'mgc'} - 1 ) . " -a $fw | ";
   $line .= "$BCP -n " .   ( $ordr{'mgc'} - 1 ) . " -s 1 -e " . ( $ordr{'mgc'} - 1 ) . " | ";
   $line .= "$MERGE -n " . ( $ordr{'mgc'} - 2 ) . " -s 0 -N 0 $gendir/${base}.p_b0 | ";
   $line .= "$B2MC -m " .  ( $ordr{'mgc'} - 1 ) . " -a $fw > $gendir/${base}.p_mgc";
   shell($line);

   $line = "rm -f $gendir/$base.r0 $gendir/$base.p_r0 $gendir/$base.b0 $gendir/$base.p_b0";
   shell($line);
}

# sub routine for formant emphasis in LSP domain
sub postfiltering_lsp($$) {
   my ( $base, $gendir ) = @_;
   my ( $file, $lgopt, $line, $i, @lsp, $d_1, $d_2, $plsp, $data );

   $file = "$gendir/${base}.mgc";
   if ($lg) {
      $lgopt = "-L";
   }
   else {
      $lgopt = "";
   }

   $line = "$LSPCHECK -m " . ( $ordr{'mgc'} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 $file | ";
   $line .= "$LSP2LPC -m " . ( $ordr{'mgc'} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt | ";
   $line .= "$MGC2MGC -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $fl - 1 ) . " -A 0.0 -G 1.0 | ";
   $line .= "$SOPR -P | $VSUM -t $fl | $SOPR -LN -m 0.5 > $gendir/${base}.ene1";
   shell($line);

   # postfiltering
   open( LSP,  "$X2X +fa < $gendir/${base}.mgc |" );
   open( GAIN, ">$gendir/${base}.gain" );
   open( PLSP, ">$gendir/${base}.lsp" );
   while (1) {
      @lsp = ();
      for ( $i = 0 ; $i < $ordr{'mgc'} && ( $line = <LSP> ) ; $i++ ) {
         push( @lsp, $line );
      }
      if ( $ordr{'mgc'} != @lsp ) { last; }

      $data = pack( "f", $lsp[0] );
      print GAIN $data;
      for ( $i = 1 ; $i < $ordr{'mgc'} ; $i++ ) {
         if ( $i > 1 && $i < $ordr{'mgc'} - 1 ) {
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

   $line = "$MERGE -s 1 -l 1 -L " . ( $ordr{'mgc'} - 1 ) . " -N " . ( $ordr{'mgc'} - 2 ) . " $gendir/${base}.lsp < $gendir/${base}.gain | ";
   $line .= "$LSPCHECK -m " . ( $ordr{'mgc'} - 1 ) . " -s " .                     ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 | ";
   $line .= "$LSP2LPC -m " .  ( $ordr{'mgc'} - 1 ) . " -s " .                     ( $sr / 1000 ) . " $lgopt | ";
   $line .= "$MGC2MGC -m " .  ( $ordr{'mgc'} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $fl - 1 ) . " -A 0.0 -G 1.0 | ";
   $line .= "$SOPR -P | $VSUM -t $fl | $SOPR -LN -m 0.5 > $gendir/${base}.ene2 ";
   shell($line);

   $line = "$VOPR -l 1 -d $gendir/${base}.ene2 $gendir/${base}.ene2 | $SOPR -LN -m 0.5 | ";
   $line .= "$VOPR -a $gendir/${base}.gain | ";
   $line .= "$MERGE -s 1 -l 1 -L " . ( $ordr{'mgc'} - 1 ) . " -N " . ( $ordr{'mgc'} - 2 ) . " $gendir/${base}.lsp > $gendir/${base}.p_mgc";
   shell($line);

   $line = "rm -f $gendir/${base}.ene1 $gendir/${base}.ene2 $gendir/${base}.gain $gendir/${base}.lsp";
   shell($line);
}

# sub routine for speech synthesis from log f0 and mel-cepstral coefficients
sub gen_wave($$$) {
   my ( $gendir, $useMSPF, $mspfStatsDir ) = @_;
   my ( $line, $lgopt, $uttId, $T, $lf0, $bap );

   print "Processing directory $gendir:\n";

   if ($lg) {
      $lgopt = "-L";
   }
   else {
      $lgopt = "";
   }

   open( UTTIDS, $corpus{'gen'} ) || die "Cannot open $!";

   while ( $uttId = <UTTIDS> ) {
      chomp($uttId);

      if ( $gm == 0 ) {

         # apply postfiltering
         if ($useMSPF) {
            postfiltering_mspf( $mspfStatsDir, $uttId, $gendir, 'mgc' );
            $mgc = "$gendir/$uttId.p_mgc";
         }
         elsif ( !$useGV && $pf_mcp != 1.0 ) {
            postfiltering_mcp( $uttId, $gendir );
            $mgc = "$gendir/$uttId.p_mgc";
         }
         else {
            $mgc = "$gendir/$uttId.mgc";
         }
      }
      else {

         # apply postfiltering
         if ($useMSPF) {
            postfiltering_mspf( $mspfStatsDir, $uttId, $gendir, 'mgc' );
            $mgc = "$gendir/$uttId.p_mgc";
         }
         elsif ( !$useGV && $pf_lsp != 1.0 ) {
            postfiltering_lsp( $uttId, $gendir );
            $mgc = "$gendir/$uttId.p_mgc";
         }
         else {
            $mgc = "$gendir/$uttId.mgc";
         }

         # MGC-LSPs -> MGC coefficients
         $line = "$LSPCHECK -m " . ( $ordr{'mgc'} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt -c -r 0.1 -g -G 1.0E-10 $mgc | ";
         $line .= "$LSP2LPC -m " . ( $ordr{'mgc'} - 1 ) . " -s " . ( $sr / 1000 ) . " $lgopt | ";
         $line .= "$MGC2MGC -m " . ( $ordr{'mgc'} - 1 ) . " -a $fw -c $gm -n -u -M " . ( $ordr{'mgc'} - 1 ) . " -A $fw -C $gm " . " > $gendir/$uttId.c_mgc";
         shell($line);

         $mgc = "$gendir/$uttId.c_mgc";
      }

      $lf0 = "$gendir/$uttId.lf0";
      $bap = "$gendir/$uttId.bap";

      if ( !$usestraight && -s $mgc && -s $lf0 ) {
         print " Synthesizing a speech waveform from $uttId.mgc and $uttId.lf0...";

         # convert log F0 to pitch
         $line = "$SOPR -magic -1.0E+10 -EXP -INV -m $sr -MAGIC 0.0 $lf0 > $gendir/$uttId.pit";
         shell($line);

         # synthesize waveform
         $lfil = `$PERL $datdir/scripts/makefilter.pl $sr 0`;
         $hfil = `$PERL $datdir/scripts/makefilter.pl $sr 1`;

         $line = "$SOPR -m 0 $gendir/$uttId.pit | $EXCITE -n -p $fs | $DFS -b $hfil > $gendir/$uttId.unv";
         shell($line);

         $line = "$EXCITE -n -p $fs $gendir/$uttId.pit | ";
         $line .= "$DFS -b $lfil | $VOPR -a $gendir/$uttId.unv | ";
         $line .= "$MGLSADF -P 5 -m " . ( $ordr{'mgc'} - 1 ) . " -p $fs -a $fw -c $gm $mgc > $gendir/$uttId.x32768.0.raw";
         shell($line);

         $line = "rm -f $gendir/$uttId.pit $gendir/$uttId.unv";
         shell($line);

         print "done\n";
      }
      elsif ( $usestraight && -s $mgc && -s $lf0 && -s $bap ) {
         print " Synthesizing a speech waveform from $uttId.mgc, $uttId.lf0, and $uttId.bap... ";

         # convert log F0 to F0
         $line = "$SOPR -magic -1.0E+10 -EXP -MAGIC 0.0 $lf0 > $gendir/$uttId.f0 ";
         shell($line);
         $T = get_file_size("$gendir/$uttId.f0 ") / 4;

         # convert mel-cepstral coefficients to spectrum
         if ( $gm == 0 ) {
            shell( "$MGC2SP -a $fw -g $gm -m " . ( $ordr{'mgc'} - 1 ) . " -l 2048 -o 2 $mgc > $gendir/$uttId.sp" );
         }
         else {
            shell( "$MGC2SP -a $fw -c $gm -m " . ( $ordr{'mgc'} - 1 ) . " -l 2048 -o 2 $mgc > $gendir/$uttId.sp" );
         }

         # convert band-aperiodicity to aperiodicity
         shell( "$MGC2SP -a $fw -g 0 -m " . ( $ordr{'bap'} - 1 ) . " -l 2048 -o 0 $bap > $gendir/$uttId.ap" );

         # synthesize waveform
         open( SYN, ">$gendir/$uttId.m" ) || die "Cannot open $!";
         printf SYN "path(path, '%s');\n", ${STRAIGHT};
         printf SYN "prm.spectralUpdateInterval = %f;\n", 1000.0 * $fs / $sr;
         printf SYN "prm.levelNormalizationIndicator = 0;\n";
         printf SYN "\n";
         printf SYN "fprintf(1, '\\nSynthesizing %s\\n');\n", "$gendir/$uttId.wav";
         printf SYN "f0_fid = fopen('%s', 'r');\n", "$gendir/$uttId.f0";
         printf SYN "sp_fid = fopen('%s', 'r');\n", "$gendir/$uttId.sp";
         printf SYN "ap_fid = fopen('%s', 'r');\n", "$gendir/$uttId.ap";
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
         printf SYN "[audio] = exstraightsynth(f0, sp, ap, %d, prm);\n", $sr;
         printf SYN "audio_fid = fopen('%s', 'w');\n", "$gendir/$uttId.x32768.0.raw";
         printf SYN "audio = fwrite(audio_fid, audio, 'float');\n";
         printf SYN "fclose(audio_fid);\n";
         printf SYN "\n";
         printf SYN "quit;\n";
         close(SYN);
         shell("$MATLAB < $gendir/$uttId.m");

         $line = "rm -f $gendir/$uttId.m $gendir/$uttId.sp $gendir/$uttId.ap $gendir/$uttId.f0";
         shell($line);

         print "done\n";
      }

      $line = "cat $gendir/$uttId.x32768.0.raw | $X2X +fs -r -o > $gendir/$uttId.raw";
      shell($line);

      $line = "$RAW2WAV -s " . ( $sr / 1000 ) . " -d $gendir $gendir/$uttId.raw";
      shell($line);

      $line = "rm -f $gendir/$uttId.raw";
      shell($line);
   }

   close(UTTIDS);
}

# sub routine for modulation spectrum-based postfilter
sub postfiltering_mspf($$$$) {
   my ( $statsDir, $base, $gendir, $type ) = @_;
   my ( $T, $line, $d, @seq );

   $T = get_file_size("$gendir/$base.$type") / $ordr{$type} / 4;

   # subtract utterance-level mean
   $line = get_cmd_utmean( "$gendir/$base.$type", $type );
   shell("$line > $gendir/$base.$type.mean");
   $line = get_cmd_vopr( "$gendir/$base.$type", "-s", "$gendir/$base.$type.mean", $type );
   shell("$line > $gendir/$base.$type.subtracted");

   for ( $d = 0 ; $d < $ordr{$type} ; $d++ ) {

      # calculate modulation spectrum/phase
      $line = get_cmd_seq2ms( "$gendir/$base.$type.subtracted", $type, $d );
      shell("$line > $gendir/$base.$type.mspec_dim$d");
      $line = get_cmd_seq2mp( "$gendir/$base.$type.subtracted", $type, $d );
      shell("$line > $gendir/$base.$type.mphase_dim$d");

      # convert
      $line = "cat $gendir/$base.$type.mspec_dim$d | ";
      $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -s $statsDir/gen/${type}_dim$d.mean | ";
      $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -d $statsDir/gen/${type}_dim$d.stdd | ";
      $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -m $statsDir/nat/${type}_dim$d.stdd | ";
      $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -a $statsDir/nat/${type}_dim$d.mean | ";

      # apply weight
      $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -s $gendir/$base.$type.mspec_dim$d | ";
      $line .= "$SOPR -m $mspfe{$type} | ";
      $line .= "$VOPR -l " . ( $mspfFFTLen / 2 + 1 ) . " -a $gendir/$base.$type.mspec_dim$d > $gendir/$base.p_$type.mspec_dim$d";
      shell($line);

      # calculate filtered sequence
      push( @seq, msmp2seq( "$gendir/$base.p_$type.mspec_dim$d", "$gendir/$base.$type.mphase_dim$d", $T ) );
   }
   open( SEQ, ">$gendir/$base.tmp" ) || die "Cannot open $!";
   print SEQ join( "\n", @seq );
   close(SEQ);
   shell("$X2X +af $gendir/$base.tmp | $TRANSPOSE -m $ordr{$type} -n $T > $gendir/$base.p_$type.subtracted");

   # add utterance-level mean
   $line = get_cmd_vopr( "$gendir/$base.p_$type.subtracted", "-a", "$gendir/$base.$type.mean", $type );
   shell("$line > $gendir/$base.p_$type");

   shell("rm -f $gendir/$base.$type.mspec_dim* $gendir/$base.$type.mphase_dim* $gendir/$base.p_$type.mspec_dim*");
   shell("rm -f $gendir/$base.$type.subtracted $gendir/$base.p_$type.subtracted $gendir/$base.$type.mean $gendir/$base.tmp");
}

# sub routine for calculating temporal sequence from modulation spectrum/phase
sub msmp2seq($$$) {
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
   open( MSP, ">$file_ms.tmp" ) || die "Cannot open $!";
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
sub get_cmd_utmean($$) {
   my ( $file, $type ) = @_;

   return "$VSTAT -l $ordr{$type} -o 1 < $file ";
}

# sub routine for shell command to subtract vector from sequence
sub get_cmd_vopr($$$$) {
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
sub get_cmd_seq2ms($$$) {
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
sub get_cmd_seq2mp($$$) {
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
sub combine_alignments($$$$$) {
   my ( $labelsFromAlignDir, $timingsFromAlignDir, $cmpScpFile, $alignDirOut, $labScpFileOut ) = @_;
   my ( $line, $base, $istr, $lstr, @iarr, @larr );

   mkdir $alignDirOut, 0755;

   open( ISCP, "$cmpScpFile" )   || die "Cannot open $!";
   open( OSCP, ">$labScpFileOut" ) || die "Cannot open $!";

   while (<ISCP>) {
      $line = $_;
      chomp($line);
      $base = `basename $line .cmp`;
      chomp($base);

      open( LAB,  "$labelsFromAlignDir/$base.lab" )  || die "Cannot open $!";
      open( IFAL, "$timingsFromAlignDir/$base.lab" ) || die "Cannot open $!";
      open( OFAL, ">$alignDirOut/$base.lab" )          || die "Cannot open $!";

      while ( ( $istr = <IFAL> ) && ( $lstr = <LAB> ) ) {
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
sub compute_mspf_stats($$$$$) {
   my ( $genDir, $monoAlignDir, $natDir, $cmpScpFile, $statsDirOut ) = @_;
   my ( $cmp, $base, $type, $natOrGen, $orgdir, $line, $d );
   my ( $str, @arr, $start, $end, $find, $j );

   mkdir $statsDirOut, 0755;
   $datDir = "$statsDirOut/_raw_data";
   mkdir $datDir, 0755;
   foreach $natOrGen ( 'nat', 'gen' ) {
      mkdir "$statsDirOut/$natOrGen";
      mkdir "$datDir/$natOrGen";
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
   open( SCP, "$cmpScpFile" ) || die "Cannot open $!";
   while (<SCP>) {
      $cmp = $_;
      chomp($cmp);
      $base = `basename $cmp .cmp`;
      chomp($base);
      print " Making data from $base.lab for modulation spectrum...";

      foreach $type ('mgc') {
         foreach $natOrGen ( 'nat', 'gen' ) {

            # determine original feature directory
            if   ( $natOrGen eq 'nat' ) { $origDir = "$natDir"; }
            else                       { $origDir = "$genDir"; }

            # subtract utterance-level mean
            $line = get_cmd_utmean( "$origDir/$base.$type", $type );
            shell("$line > $datDir/$natOrGen/$base.$type.mean");
            $line = get_cmd_vopr( "$origDir/$base.$type", "-s", "$datDir/$natOrGen/$base.$type.mean", $type );
            shell("$line > $datDir/$natOrGen/$base.$type.subtracted");

            # extract non-silence frames
            if ( @slnt > 0 ) {
               shell("rm -f $datDir/$natOrGen/$base.$type.subtracted.no-sil");
               shell("touch $datDir/$natOrGen/$base.$type.subtracted.no-sil");
               open( F, "$monoAlignDir/$base.lab" ) || die "Cannot open $!";
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

sub train_mspf($$) {
   my ( $modelDirIn, $monoAlignDir, $fullLabDir, $natDir ) = @_;
   my ( $modelDirOut, $genDir );

   print_time("training modulation spectrum-based postfilter");

   $modelDirOut = "$modelDirIn-mspf";
   mkdir "$modelDirOut", 0755;

   $genDir = "$modelDirOut/_gen";
   mkdir $genDir, 0755;

   # make scp and fullcontext forced-aligned label files
   combine_alignments( $fullLabDir, $monoAlignDir, $scp{'trn'}, "$modelDirOut/_full-from-mono-fal", "$genDir/gen_fal.scp" );

   # config file for aligned parameter generation
   open( CONF, ">$genDir/apg.cnf" ) || die "Cannot open $!";
   print CONF "MODELALIGN = T\n";
   close(CONF);

   # synthesize speech parameters using model alignment
   shell("$HMGenS -C $genDir/apg.cnf -S $genDir/gen_fal.scp -c $pgtype -H $modelDirIn/cmp.mmf -N $modelDirIn/dur.mmf -M $genDir $modelDirIn/mlist_cmp.lst $modelDirIn/mlist_dur.lst");

   # estimate statistics for modulation spectrum
   compute_mspf_stats( $genDir, $monoAlignDir, $natDir, $scp{'trn'}, "$modelDirOut/stats" );
}

sub expectation_maximization($$$) {
   my ( $modelDirIn, $numIts, $tag ) = @_;
   my ( $modelDirOut, $set, $type, $dirIn, $it );

   print_time("embedded reestimation ($tag)");

   $modelDirOut = "$modelDirIn-$numIts";
   mkdir "$modelDirOut", 0755;

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/mlist_cmp.lst $modelDirOut/");
   shell("cp $modelDirIn/mlist_dur.lst $modelDirOut/");

   foreach $set (@SET) {
      foreach $type ( @{ $ref{$set} } ) {
         shell("cp $modelDirIn/${set}_$type.inf $modelDirOut/");
      }
   }

   $dirIn = $modelDirIn;
   for ( $it = 1 ; $it <= $numIts ; $it++ ) {
      print("\n\nIteration $it of Embedded Re-estimation\n");
      shell("$HERest{'ful'} -H $dirIn/cmp.mmf -N $dirIn/dur.mmf -M $modelDirOut -R $modelDirOut $dirIn/mlist_cmp.lst $dirIn/mlist_dur.lst");

      $dirIn = $modelDirOut;
   }
}

sub decision_tree_cluster($$) {
   my ( $modelDirIn, $tag ) = @_;
   my ( $modelDirOut, $labelType, $set, $type, $phone );

   $modelDirOut = "$modelDirIn-clus";
   mkdir "$modelDirOut", 0755;
   mkdir "$modelDirOut/_acc", 0755;

   $labelType = get_label_type($modelDirIn);
   if ( $labelType eq "mono" ) {
      print_time("copying monophone mmf to fullcontext one ($tag)");

      shell("echo full > $modelDirOut/_acc/label_type");
      shell("cp $lst{'ful'} $modelDirOut/_acc/mlist_cmp.lst");
      shell("cp $lst{'ful'} $modelDirOut/_acc/mlist_dur.lst");

      foreach $set (@SET) {
         open( EDFILE, ">$modelDirOut/_acc/m2f_$set.hed" ) || die "Cannot open $!";
         open( LIST,   "$modelDirIn/mlist_$set.lst" ) || die "Cannot open $!";

         print EDFILE "// copy monophone models to fullcontext ones\n";
         print EDFILE "CL \"$lst{'ful'}\"\n\n";    # CLone monophone to fullcontext

         print EDFILE "// tie state transition probability\n";
         while ( $phone = <LIST> ) {

            # trimming leading and following whitespace characters
            $phone =~ s/^\s+//;
            $phone =~ s/\s+$//;

            # skip a blank line
            if ( $phone eq '' ) {
               next;
            }
            print EDFILE "TI T_${phone} {*-${phone}+*.transP}\n";    # TIe transition prob
         }
         close(LIST);
         close(EDFILE);

         shell("$HHEd{'trn'} -T 1 -H $modelDirIn/$set.mmf -w $modelDirOut/_acc/$set.mmf $modelDirOut/_acc/m2f_$set.hed $modelDirIn/mlist_$set.lst");
      }
   }
   else {
      print_time("untying the parameter sharing structure ($tag)");

      shell("cp $modelDirIn/label_type $modelDirOut/_acc/");
      shell("cp $modelDirIn/mlist_cmp.lst $modelDirOut/_acc/");
      shell("cp $modelDirIn/mlist_dur.lst $modelDirOut/_acc/");

      foreach $set (@SET) {
         make_edfile_untie( $set, "$modelDirOut/_acc/untie_$set.hed" );
         shell("$HHEd{'trn'} -T 1 -H $modelDirIn/$set.mmf -w $modelDirOut/_acc/$set.mmf $modelDirOut/_acc/untie_$set.hed $modelDirIn/mlist_$set.lst");
      }
   }

   print_time("fullcontext embedded reestimation ($tag)");

   print("\n\nEmbedded Re-estimation\n");
   shell("$HERest{'ful'} -H $modelDirOut/_acc/cmp.mmf -N $modelDirOut/_acc/dur.mmf -M $modelDirOut/_acc -R $modelDirOut/_acc -C $cfg{'nvf'} -s $modelDirOut/_acc/cmp.stats -w 0.0 $modelDirOut/_acc/mlist_cmp.lst $modelDirOut/_acc/mlist_dur.lst");

   print_time("tree-based context clustering ($tag)");

   # convert cmp stats to duration ones
   convstats( "$modelDirOut/_acc/cmp.stats", "$modelDirOut/_acc/dur.stats" );

   shell("cp $modelDirOut/_acc/label_type $modelDirOut/");
   shell("cp $modelDirOut/_acc/mlist_cmp.lst $modelDirOut/");
   shell("cp $modelDirOut/_acc/mlist_dur.lst $modelDirOut/");

   foreach $set (@SET) {
      shell("mv $modelDirOut/_acc/$set.mmf $modelDirOut/$set.mmf");

      foreach $type ( @{ $ref{$set} } ) {
         make_edfile_state( $type, "$modelDirOut/_acc/$set.stats", "$modelDirOut/cxc_${set}_$type.hed", "$modelDirOut/${set}_$type.inf" );
         shell("$HHEd{'trn'} -T 3 -C $cfg{$type} -H $modelDirOut/$set.mmf $mdl{$type} -w $modelDirOut/$set.mmf $modelDirOut/cxc_${set}_$type.hed $modelDirOut/mlist_$set.lst");
      }
   }

   # (FIXME : remove _acc)
}

sub add_1_mix_comp($$) {
   my ( $modelDirIn, $tag ) = @_;
   my ($modelDirOut);

   print_time("increasing the number of mixture components ($tag)");

   $modelDirOut = "$modelDirIn-mix+1";
   mkdir "$modelDirOut", 0755;

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/mlist_cmp.lst $modelDirOut/");
   shell("cp $modelDirIn/mlist_dur.lst $modelDirOut/");

   $labelType = get_label_type($modelDirIn);
   if ( $labelType ne "mono" ) {
      foreach $set (@SET) {
         foreach $type ( @{ $ref{$set} } ) {
            shell("cp $modelDirIn/${set}_$type.inf $modelDirOut/");
         }
      }
   }

   make_edfile_upmix( "cmp", "$modelDirOut/_upmix_cmp.hed" );
   shell("$HHEd{'trn'} -T 1 -H $modelDirIn/cmp.mmf -w $modelDirOut/cmp.mmf $modelDirOut/_upmix_cmp.hed $modelDirIn/mlist_cmp.lst");

   shell("cp $modelDirIn/dur.mmf $modelDirOut/");
}

sub estimate_semi_tied_cov($$) {
   my ( $modelDirIn, $tag ) = @_;
   my ( $modelDirOut, $opt );

   print_time("semi-tied covariance matrices ($tag)");

   $modelDirOut = "$modelDirIn-stc";
   mkdir "$modelDirOut", 0755;

   shell("cp $modelDirIn/label_type $modelDirOut/");
   shell("cp $modelDirIn/mlist_cmp.lst $modelDirOut/");
   shell("cp $modelDirIn/mlist_dur.lst $modelDirOut/");

   foreach $set (@SET) {
      foreach $type ( @{ $ref{$set} } ) {
         shell("cp $modelDirIn/${set}_$type.inf $modelDirOut/");
      }
   }

   make_stc_base("$modelDirOut/_stc.base");
   make_stc_config( "$modelDirOut/_stc.base", "$modelDirOut/_stc.cnf" );

   $opt = "-C $modelDirOut/_stc.cnf -K $modelDirOut stc -u smvdmv";

   shell("$HERest{'ful'} -H $modelDirIn/cmp.mmf -N $modelDirIn/dur.mmf -M $modelDirOut -R $modelDirOut $opt $modelDirIn/mlist_cmp.lst $modelDirIn/mlist_dur.lst");
}

sub get_label_type($) {
   my ($modelDirIn) = @_;
   my ($labelType);

   open( LABTYPE, "$modelDirIn/label_type" ) || die "Cannot open $!";
   $labelType = <LABTYPE>;
   chomp($labelType);
   close LABTYPE;

   return $labelType;
}

sub fal_on_train_corpus($$$) {
   my ( $modelDirIn, $monoOrFull, $tag ) = @_;
   my ( $dirOut, $labelType, $mlfFile );

   print_time("forced alignment ($tag)");

   $dirOut = "$modelDirIn-fal";
   mkdir "$dirOut", 0755;

   $labelType = get_label_type($modelDirIn);
   if ( $labelType eq "mono" ) {
      $mlfFile = "$mlf{'mon'}";
   }
   else {
      $mlfFile = "$mlf{'ful'}";
   }

   shell("$HSMMAlign -I $mlfFile -S $scp{'trn'} -H $modelDirIn/cmp.mmf -N $modelDirIn/dur.mmf -m $dirOut $modelDirIn/mlist_cmp.lst $modelDirIn/mlist_dur.lst");
}

sub eval_mono($$$) {
   my ( $modelDirIn, $evalCmpScpFile, $tag ) = @_;
   my ($dirOut);

   print_time("computing test set log probability ($tag)");

   $dirOut = "$modelDirIn-eval";
   mkdir "$dirOut", 0755;

   if (-s $evalCmpScpFile) {
      shell("$HERest{'tst'} -I $mlf{'mon'} -S $evalCmpScpFile -H $modelDirIn/cmp.mmf -N $modelDirIn/dur.mmf -M /dev/null -R /dev/null $modelDirIn/mlist_cmp.lst $modelDirIn/mlist_dur.lst");
   }
   else {
      print("(skipping since specified corpus is empty)\n\n");
   }

   # FIXME : write summary of TSLP to a file

   print_time("forced alignment on test corpus ($tag)");

   mkdir "$dirOut/fal", 0755;

   shell("$HSMMAlign -I $mlf{'mon'} -S $evalCmpScpFile -H $modelDirIn/cmp.mmf -N $modelDirIn/dur.mmf -m $dirOut/fal $modelDirIn/mlist_cmp.lst $modelDirIn/mlist_dur.lst");
}

sub eval_full($$$$) {
   my ( $modelDirIn, $evalMListFile, $evalCmpScpFile, $tag ) = @_;
   my ( $dirOut, $set, $edFile );

   $dirOut = "$modelDirIn-eval";
   mkdir "$dirOut", 0755;
   mkdir "$dirOut/_all", 0755;

   print_time("making unseen models ($tag)");

   foreach $set (@SET) {
      $edFile = "$dirOut/_all/mkunseen_$set.hed";
      make_edfile_mkunseen( $modelDirIn, $evalMListFile, $set, $edFile, "$dirOut/_all/mlist_$set.lst" );
      shell("$HHEd{'trn'} -T 1 -H $modelDirIn/$set.mmf -w $dirOut/_all/$set.mmf $edFile $modelDirIn/mlist_$set.lst");
   }

   print_time("computing log probability ($tag)");

   if (-s $evalCmpScpFile) {
      shell("$HERest{'tst'} -I $mlf{'ful'} -S $evalCmpScpFile -H $dirOut/_all/cmp.mmf -N $dirOut/_all/dur.mmf -M /dev/null -R /dev/null $dirOut/_all/mlist_cmp.lst $dirOut/_all/mlist_dur.lst");
   }
   else {
      print("(skipping since specified corpus is empty)\n\n");
   }

   # FIXME : write summary of TSLP to a file

   print_time("forced alignment on test corpus ($tag)");

   mkdir "$dirOut/fal", 0755;

   shell("$HSMMAlign -I $mlf{'ful'} -S $evalCmpScpFile -H $dirOut/_all/cmp.mmf -N $dirOut/_all/dur.mmf -m $dirOut/fal $dirOut/_all/mlist_cmp.lst $dirOut/_all/mlist_dur.lst");

   # FIXME : remove _all directory
}

sub full_synth($$$$$$) {
   my ( $modelDirIn, $genMListFile, $genLabScpFile, $genMethod, $genType, $tag ) = @_;
   my ( $dirOut, $set, $edFile, $synthDirOut );

   $dirOut = "$modelDirIn-synth";
   mkdir "$dirOut", 0755;
   mkdir "$dirOut/_all", 0755;

   print_time("making unseen models ($tag)");

   foreach $set (@SET) {
      $edFile = "$dirOut/_all/mkunseen_$set.hed";
      make_edfile_mkunseen( $modelDirIn, $genMListFile, $set, $edFile, "$dirOut/_all/mlist_$set.lst" );
      shell("$HHEd{'trn'} -T 1 -H $modelDirIn/$set.mmf -w $dirOut/_all/$set.mmf $edFile $modelDirIn/mlist_$set.lst");
   }

   # FIXME : actually use genMethod, and add more possible generation methods
   $synthDirOut = "$dirOut/$genMethod-c$genType";
   mkdir "$synthDirOut", 0755;

   print_time("generating speech parameter sequences ($tag)");

   # generate parameter
   shell("$HMGenS -S $genLabScpFile -c $genType -H $dirOut/_all/cmp.mmf -N $dirOut/_all/dur.mmf -M $synthDirOut $dirOut/_all/mlist_cmp.lst $dirOut/_all/mlist_dur.lst");

   # FIXME : remove _all directory

   print_time("synthesizing waveforms ($tag)");

   # (FIXME : useMSPF should be part of gen type)

   # FIXME : allow different types of gen / postfiltering
   gen_wave( $synthDirOut, 0, "" );
}

##################################################################################################

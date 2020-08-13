#!/usr/bin/perl -w
#time mark
#2012Aug17,V1.0.0.4 Modifying NPC target with 0 weight
# ----------------------------------------------------------------------
use strict;
use Switch;
use Getopt::Long;
use File::Copy;

my $debug = 0;

my $Cur_MRN = "";
my $Cur_Name = "";
my $Cur_Plan = "";
my $Pat_Data_Path = "";
Getopt::Long::GetOptions(
    'm=s' => \$Cur_MRN,
    'n=s' => \$Cur_Name,
    'p=s' => \$Cur_Plan,
    'l=s' => \$Pat_Data_Path);    

##:define default directory path and default message
my $PatientDataBaseHome = "/pinnacle_patient_expansion/NewPatients/";
my $SystemScriptHome = "/usr/local/adacnew/PinnacleSiteData/Scripts/IMRT_NPC/";
if($debug){
   $PatientDataBaseHome = "/home/p3rtp/Backup/";
   $SystemScriptHome    = "/home/p3rtp/Backup/IMRT_NPC/";
};

my $BinHome = $SystemScriptHome."bin/";
my $ScriptTempDir = $SystemScriptHome."temp/";
my $BeamTemplate = $SystemScriptHome."BeamTemplate.txt";
my $IMRTTemplate = $SystemScriptHome."NPC_Config/NPC_Obj_Init";
my $NPC_Contour =  $SystemScriptHome."NPC_Config/NPC_Contour";
my $NPC_Contour_List = $SystemScriptHome."NPC_Config/NPC_Contour_List";
my $NPC_RemoveRoi_List = $SystemScriptHome."NPC_Config/NPC_RemoveRoi_List";

#temp file
my $ROIList = $ScriptTempDir."ROI_List.txt";
my $ROIListModify = $ScriptTempDir."ROI_Modify.txt";


my $FIN_SCRIPT = "";
my $CurPlanRoiFile = "";
if($debug){
   $FIN_SCRIPT = $ScriptTempDir.$Cur_MRN."CurrentIMRTStepOne.Script.p3rtp";   
   $CurPlanRoiFile =  $PatientDataBaseHome."IMRT_NPC/Patient_17587/Plan_5/plan.roi";
}else{
   $FIN_SCRIPT = $ScriptTempDir.$Cur_MRN."CurrentIMRTStepOne.Script.p3rtp";
   $CurPlanRoiFile =  $PatientDataBaseHome.$Pat_Data_Path."/plan.roi";
};
##:paln parameters define
my $Globel_BeamNum = "";           #plan beam number
my $Globel_PlanType = 0;           #0 - 6 type
my @Globel_Prescriptions = (); 		#Prescription of One Fraction (180-200cGy)
my @Globel_TargetNameList = ();		#Target name (PGTV,#0,PTV,#1)

my @Globel_ROIList = ();
my @Globel_ROIModifyList = ();		#Target name (0,PTV,TARGET)
my $Globel_FractionNum = "";		#Fraction numbers(28F)
my $Globel_TotalDose = "";			#Total Dose = $Prescription * $Globel_FractionNum

my %Globel_RoiListData = ();               #Roi_list for hash list

##:sub-function define
sub CurTime{
	my @CurTime = localtime;
	my $yyyymmdd = "";
	$yyyymmdd = $CurTime[5]+1900;
	my $tmpTime = $CurTime[4]+1;
	$tmpTime = "0$tmpTime" if $tmpTime < 10;
	$yyyymmdd .= $tmpTime;
	$tmpTime = $CurTime[3];
	$tmpTime = "0$tmpTime" if $tmpTime < 10;
	$yyyymmdd .= $tmpTime;
	print "$yyyymmdd\n" if $debug;
	return $yyyymmdd
}
sub ROICheck{##Read Plan ROI file
	my ($SourceFile,$TargetFile,$FinScripFile) = @_;
	my $line = '';
	open(FINAL,">>$FinScripFile") or die "unable to open $FinScripFile: $!";
	if (-r $SourceFile) {
		open(DATA, "<$SourceFile") or die "Unable to open $SourceFile: $!";   
		open(OUT,">$TargetFile") or die "unable to open $TargetFile: $!";
		#record ROI position
		my $cnt = 0;  
		while ($line = <DATA>) {
			chomp($line);
			#match ROI name
			if($line =~ /^           name:(.*)/){ 
				$line = $1;			 
				print OUT "$cnt\t$line\n" if $debug;
				push(@Globel_ROIList,"$cnt\t$line");  # save roi to list;
				$cnt++;
			};
		};
		close(DATA);
		close(OUT);
	}else{
		die "$SourceFile is not readable\n";
	};
	#check patient
    #open(OUT,"<$TargetFile") or die "unable to open $TargetFile: $!";
    my $tmp = 0;
	my $PTVmark = 0;
	my $PGTVmark = 0;
    foreach $line (@Globel_ROIList){
       if(!defined($line)) {next;}
	   #if($line =~ /Patient$/i){ $tmp = 1;};
	   if(($line =~ /PTV$/i) || ($line =~ /PTV[0-9]$/i)){ $PTVmark = $PTVmark + 1; };
	   if(($line =~ /PGTV$/i) || ($line =~ /PGTV[0-9]$/i) || ($line =~ /PGTVn[xd]$/)){	$PGTVmark = $PGTVmark + 1;};   
    };   
    
	if($PGTVmark == 1 && $PTVmark == 1){$Globel_PlanType = 1;}; #PGTV and PTV both exist
	if($PGTVmark == 1 && $PTVmark == 0){$Globel_PlanType = 2;}; #PGTV only
	if($PGTVmark == 0 && $PTVmark == 1){$Globel_PlanType = 3;}; #PTV only	
	if($PGTVmark == 2 && $PTVmark == 2){$Globel_PlanType = 4;}; #PTV1,PTV2,PGTV1,PGTV2	
	if($PGTVmark == 2 && $PTVmark == 0){$Globel_PlanType = 5;}; #PGTV1,PGTV2
	if($PGTVmark == 0 && $PTVmark == 2){$Globel_PlanType = 6;}; #PTV1,PTV2
    if($Globel_PlanType == 0){
	   print FINAL "WarningMessage = \"$PGTVmark,$PTVmark,$Globel_PlanType,Checking Contour_Patients!\";\n";    #pre_define Pinnacle Non_normal exit
	   close(FINAL);      #exit programe when Contour_Patients is not define
	   goto PerlEND; #exit perl programe
    };
    close(FINAL);
    #close(OUT);
};
sub CreatRingNT{
	my ($ROIListFile,$ROIModifyFile,$FinScripFile) = @_;
	my ($targetmark,$oarmark,$phantommark,$tempmark) = ('TARGET','OAR','PHANTOM','CONTOURS');
	my $tempName = '';
	my @tempData = ();
	my $TotalROINum = 0; #roi total number
	my $tmpCnt = 0; #mark counts
	my $temp = 0; 
	my $patientPos = ""; #Patient contours position	
	my $targetPos = ""; #target pos	
	
	
	open(OUT,">>$FinScripFile") or die "unable to open $FinScripFile: $!"; #Pinn script file	
	#print OUT "WindowList .CTSim .PanelList .\#\"\#2\" .GotoPanel = \"FunctionLayoutIcon2\";\n";
	#print OUT "WindowList .NewROISpreadsheet .Create = \"ROISpreadsheetButton\";\n";
	#print OUT "RoiLayout .Index = 1;\n";
	
	@Globel_ROIModifyList = ();
	$tmpCnt = 0;
	foreach my $line (@Globel_ROIList){
	   if(!defined($line)) {next;}
	   $tmpCnt = $tmpCnt + 1;	  #counting Total roi numbers  	   
	   @tempData= split(/\t/,$line);
	   chomp($tempData[-1]);
	   $tempData[1] =~ s/^\s+//;
	   $tempData[1] =~ s/\s+$//;	
	   print "target: $tempData[1];\n";     
	   #target
	   #if(($tempData[1] eq "PGTV") || ($tempData[1] eq "PGTVnd")){
	   if($tempData[1] eq "PGTV") {
	       $tempName = $tempData[1];		   
	       push(@Globel_TargetNameList,$tempName,$tempData[0]);   #save targets name,position       
	       #print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"$tempName\";\n";
		   #push(@Globel_ROIModifyList, "$tempData[0]\t$tempName\t$targetmark");
	       #next;
	   };	   
	   #if($tempData[1] eq "PTV1" || $tempData[1] eq "PTV2"){
	   if($tempData[1] eq "PTV1"){
	       $tempName = $tempData[1];    
	       push(@Globel_TargetNameList,$tempName,$tempData[0]); #save targets name     
		   #print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"$tempName\";\n";
	       #push(@Globel_ROIModifyList, "$tempData[0]\t$tempName\t$targetmark");
	       #next;
	   };
	   #OAR_Head
	   if($tempData[1] =~ /Len[-_]L(.*)/i || $tempData[1] =~ /Lens[-_]L(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Len_L\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tLen_L\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Len[-_]R(.*)/i || $tempData[1] =~ /Lens[-_]R(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Len_R\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tLen_R\t$oarmark");
	       next;
	   };	
	   if($tempData[1] =~ /Parotid[-_]R(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Parotid_R\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tParotid_R\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Parotid[-_]L(.*)/i){
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Parotid_L\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tParotid_L\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Pituitary(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Pituitary\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tPituitary\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Temp(.*)lobe[-_]R(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Temp.lobe_R\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tTemp.lobe_R\t$oarmark");
	       next;
	   };	
	   if($tempData[1] =~ /Temp(.*)lobe[-_]L(.*)/i){ 
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Temp.lobe_L\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tTemp.lobe_L\t$oarmark\n");
	       next;
	   };	
	   if($tempData[1] =~ /Temp(.*)joint[-_]R(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Temp.joint_R\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tTemp.joint_R\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Temp(.*)joint[-_]L(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Temp.joint_L\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tTemp.joint_L\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Mandible(.*)/i){     
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Mandible\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tMandible\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Brainstem$/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Brainstem\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tBrainstem\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Brainstem\+(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Brainstem_2mmPRV\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tBrainstem_2mmPRV\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Opt(.*)nerve[-_]L$/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Opt.nerve_L\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tOpt.nerve_L\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Opt(.*)nerve[-_]L\+(.*)/i){	
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Opt.nerve_L_2mmPRV\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tOpt.nerve_L_2mmPRV\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Opt(.*)nerve[-_]R$/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Opt.nerve_R\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tOpt.nerve_R\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Opt(.*)nerve[-_]R\+(.*)/i){	
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Opt.nerve_R_2mmPRV\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tOpt.nerve_R_2mmPRV\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Opt(.*)chiasm$/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Opt.chiasm\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tOpt.chiasm\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Opt(.*)chiasm\+(.*)$/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Opt.chiasm_2mmPRV\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tOpt.chiasm_2mmPRV\t$oarmark");
	       next;
	   };
	   #OAR_chest	
	   if($tempData[1] =~ /Larynx(.*)/i){     
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Larynx\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tLarynx\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Trachea(.*)/i){       
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Trachea\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tTrachea\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Esophagus(.*)/i){       
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Esophagus\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tEsophagus\t$oarmark");
	       next;
	   };
	   if(($tempData[1] =~ /cord$/i) || ($tempData[1] =~ /cord[0-9]$/i)){	       
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Cord\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tCord\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /cord\+(.*)/i){	       
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Cord_5mmPRV\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tCord_5mmPRV\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Lung[-_]R(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Lung_R\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tLung_R\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Lung[-_]L(.*)/i){		     
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Lung_L\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tLung_L\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Lung[-_]ALL(.*)/i || $tempData[1] =~ /Lung[-_]total(.*)/i) {      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Lung_Total\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tLung_Total\t$oarmark");
	       next;
	   };	
	   if($tempData[1] =~ /Heart(.*)/i){ 	       
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Heart\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tHeart\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Stomach(.*)/i){ 	       
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Stomach\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tStomach\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Pancreas(.*)/i){ 	       
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Pancreas\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tPancreas\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Spleen(.*)/i){ 	       
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Spleen\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tSpleen\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Liver(.*)/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Liver\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tLiver\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Kidney[-_]R(.*)/i){      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Kidney_R\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tKidney_R\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Kidney[-_]L(.*)/i){      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Kidney_L\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tKidney_L\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Kidney[-_]ALL(.*)/i || $tempData[1] =~ /Kidney[-_]total(.*)/i) {      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Kidney_Total\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tKidney_Total\t$oarmark");
	       next;
	   };		
	   #OAR_Abdoman
	   if($tempData[1] =~ /Bladder(.*)/i){ 	     
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Bladder\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tBladder\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /Rectum(.*)/i){ 	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Rectum\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tRectum\t$oarmark");
	       next;
	   };
	   if(($tempData[1] =~ /small(.*)/i) || ($tempData[1] =~ /(.*)intestine/i)){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Small.intestine\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tSmall.intestine\t$oarmark");
	       next;
	   };	
	   if ($tempData[1] =~ /(.*)bowel/i){  
	   print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Bowel\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tBowel\t$oarmark");
	       next;
	   };    
	   if($tempData[1] =~ /fem(.*)l$/i){	      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Femoral.head_L\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tFemoral.head_L\t$oarmark");
	       next;
	   };
	   if($tempData[1] =~ /fem(.*)r$/i){      
	       print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Femoral.head_R\";\n";
	       push(@Globel_ROIModifyList, "$tempData[0]\tFemoral.head_R\t$oarmark");
	       next;
	   };	  
	  
	   #if($tempData[1] eq "Patient"){
	       #$patientPos = $tempData[0];
	       #print OUT "RoiList.Current = $tempData[0]\n";
	       #print OUT "RoiList.\#\"\#$tempData[0]\".Name = \"Patient\";\n";
	       #push(@Globel_ROIModifyList, "$tempData[0]\tPatient\t$tempmark");
	       #next;
	   #};
	   push(@Globel_ROIModifyList, "$tempData[0]\t$tempData[1]\t$tempmark");
	};
	#print OUT "WindowList .NewROISpreadsheet .Unrealize = \"Close ROI Spreadsheet\";\n";
		
	$TotalROINum = $tmpCnt;
	#================== input Ring to ROi_List_Modifying
	open(ROI_MOD,"<$NPC_Contour_List") or die"can't open $NPC_Contour_List";
	while (my $line = <ROI_MOD>){
		@tempData= split(/\t/,$line);
		chomp($tempData[-1]);
		$tempData[1] =~ s/^\s+//;
		$tempData[1] =~ s/\s+$//;
		$tempData[0]=$TotalROINum + $tempData[0];
		push(@Globel_ROIModifyList, "$tempData[0]\t$tempData[1]\t$tempmark");
	};
	close(ROI_MOD);
	#====push hash Array for using
	open (AAA,">$ROIListModify") or die "no ";
	foreach my $line (@Globel_ROIModifyList){ 
		@tempData= split(/\t/,$line);
		$tempData[1] =~ s/^\s+//; #remove white space
		$tempData[1] =~ s/\s+$//;
		$Globel_RoiListData{$tempData[1]} = $tempData[0]; #Roi Hash{Name} = Position
		print AAA "$tempData[0],$tempData[1]\n";
	};
	close(AAA);
	#===========================ROI_ Expansion/ contraction
	print OUT "WindowList .CTSim .PanelList .\#\"\#2\" .GotoPanel = \"FunctionLayoutIcon2\";\n";
	print OUT "WindowList .RoiExpandWindow .Create = \"ROI Expansion/Contraction...\";\n";	
	
	my @CurTarget = (); #Target Name_Postion
	my @Target_Copy = (); #temp data
	my ($SaveTargetName,$SaveTargetPos) = (undef,undef);
	my ($PTVminiPGTVposition,$PTVminiPGTVname,$PTVminiPGTVpos) = (undef,undef,undef);
	
	my $CurROIPos = $TotalROINum;  # Cur ROI position
	#----------------------------------
	open(ROICON,"<$NPC_Contour") or die "unable to open";
	my $roi = "";
	while($roi = <ROICON>){
	    if($roi =~ /^\s*$/){next;};
		if(!defined($roi)){next;};
		my @CurTarget = split(/\t/,$roi);
		chomp($CurTarget[-1]);
		my @dataRoiList = @CurTarget;		
		my $List_Length=scalar(@CurTarget);
		my $Current_Cnt = 0;
		while($Current_Cnt<($List_Length)){
			shift(@dataRoiList);
			$roi = $CurTarget[$Current_Cnt];
			print "\$roi = $roi;\$Current_Cnt=$Current_Cnt;$List_Length \n" if $debug;
			
			switch:{
				if($roi == 0){					
					$SaveTargetName = shift(@dataRoiList);#target name
					$SaveTargetPos = $Globel_RoiListData{$SaveTargetName};								
					Printing:print OUT "IF .RoiList .\#\"\#$SaveTargetPos\" .RoiExpandState .Is .Source .THEN .RoiList .\#\"\#$SaveTargetPos\" .ResetRoiExpandState .ELSE .RoiList .\#\"\#$SaveTargetPos\" .RoiExpandState = \"Source\";\n";
					print OUT "RoiExpandControl .CheckTargetRoi = RoiList .\#\"\#$SaveTargetPos\" .Address;\n";					
				};
				if($roi == 1){
					#
					$SaveTargetName = shift(@dataRoiList);
					$SaveTargetPos	= $Globel_RoiListData{$SaveTargetName};
					print OUT "IF .RoiList .\#\"\#$SaveTargetPos\" .RoiExpandState .Is .\#\"Avoid Interior\".THEN .RoiList .\#\"\#$SaveTargetPos\" .ResetRoiExpandState .ELSE .RoiList .\#\"\#$SaveTargetPos\" .RoiExpandState = \"Avoid Interior\";\n";
					print OUT "RoiExpandControl .CheckTargetRoi = RoiList .\#\"\#$SaveTargetPos\" .Address;\n";
					#last switch;
				};
				if($roi == 2){
					#shift(@dataRoiList);#remove Varab 1
					$SaveTargetName = shift(@dataRoiList);
					$SaveTargetPos	= $Globel_RoiListData{$SaveTargetName};
					print OUT "IF .RoiList .\#\"\#$SaveTargetPos\" .RoiExpandState .Is .\#\"Avoid Exterior\".THEN .RoiList .\#\"\#$SaveTargetPos\" .ResetRoiExpandState .ELSE .RoiList .\#\"\#$SaveTargetPos\" .RoiExpandState = \"Avoid Exterior\";\n";
					print OUT "RoiExpandControl .CheckTargetRoi = RoiList .\#\"\#$SaveTargetPos\" .Address;\n";
					#last switch;
				};
				if($roi ==10){
					#shift(@dataRoiList);#remove Varab 1
					$roi = shift(@dataRoiList);#margin number
					print OUT "RoiExpandControl .ConstantPadding = \"$roi\";\n";
					print OUT "RoiExpandControl .UseConstantPadding = \"1\";\n"; 
				};
				if($roi ==11){
					#shift(@dataRoiList);#remove Varab 1
					my $Negx = shift(@dataRoiList);
					my $Posx = shift(@dataRoiList);
					my $Negy = shift(@dataRoiList);
					my $Posy = shift(@dataRoiList);
					my $Negz = shift(@dataRoiList);
					my $Posz = shift(@dataRoiList);
					$Current_Cnt = $Current_Cnt+5;   #remove 5 more data
					
					print OUT "RoiExpandControl .NegXPadding = \"$Negx\";\n";
					print OUT "RoiExpandControl .UseConstantPadding = \"0\";\n";
					print OUT "RoiExpandControl .PosXPadding = \"$Posx\";\n";
					print OUT "RoiExpandControl .UseConstantPadding = \"0\";\n";
					print OUT "RoiExpandControl .NegYPadding = \"$Negy\";\n";
					print OUT "RoiExpandControl .UseConstantPadding = \"0\";\n";
					print OUT "RoiExpandControl .PosYPadding = \"$Posy\";\n";
					print OUT "RoiExpandControl .UseConstantPadding = \"0\";\n";
					print OUT "RoiExpandControl .NegZPadding = \"$Negz\";\n";
					print OUT "RoiExpandControl .UseConstantPadding = \"0\";\n";
					print OUT "RoiExpandControl .PosZPadding = \"$Posz\";\n";
					print OUT "RoiExpandControl .UseConstantPadding = \"0\";\n";
				};
				if($roi ==20){
					#shift(@dataRoiList);#remove Varab 1
					$SaveTargetName = shift(@dataRoiList);#margin number				
					print OUT "RoiExpandControl .TargetRoiName = \"$SaveTargetName\";\n"; 
					print OUT "RoiExpandControl .CreateNewTarget = \"0\";\n"; 
				};
				if($roi ==21|$roi == 22){ #create new ROI
					#shift(@dataRoiList);#remove Varab 1
					$SaveTargetName = shift(@dataRoiList);#margin number					
					print OUT "RoiExpandControl .TargetRoiName = \"$SaveTargetName\";\n"; 
					print OUT "RoiExpandControl .CreateNewTarget = \"1\";\n";
				};
				if($roi ==30){
					print OUT "RoiExpandControl .Expand = \"1\";\n";
					print OUT "RoiExpandControl .DoExpand = \"Expand\";\n"; 
					print OUT "RoiList .\#\"*\" .ResetRoiExpandState = \"Clear All\";\n";
				};
				if($roi ==31){
					print OUT "RoiExpandControl .Expand = \"1\";\n";
					print OUT "RoiExpandControl .DoExpand = \"Contract\";\n"; 
					print OUT "RoiList .\#\"*\" .ResetRoiExpandState = \"Clear All\";\n";
				};
				if($roi ==32){
					print OUT "RoiExpandControl .DoRingExpansion = \"Create Ring ROI\";\n"; 
					print OUT "RoiList .\#\"*\" .ResetRoiExpandState = \"Clear All\";\n";
				};
			};
			$Current_Cnt = $Current_Cnt+2;
		};
	};
	close(ROICON);
	#open(REMOVE,"<$NPC_RemoveRoi_List") or die "unable $NPC_RemoveRoi_List\n";
	#while($roi = <REMOVE>){
#		if($roi =~ /^\s*$/){next;};
#		if(!defined($roi)){next;};
#		chomp($roi);
#		print OUT "RoiList .Current = \"$roi\";\n";
#		print OUT "CancelRoiEditing = \"Delete Selected ROI   ($roi)\";\n";

#	print OUT "DestroyCurrentROI = \"Delete Selected ROI   ($roi)\";\n";
		
#	};
#	close(REMOVE);
	#==============================
	
	
	
	#display phantom contours
	foreach my $data(@Globel_ROIModifyList){
	   chomp($data);
	   if(!defined($data)) {next;};	   
	   @tempData = split(/\t/,$data);
	   if($tempData[2] eq "PHANTOM"){
	      print OUT "RoiList .Current = $tempData[0];\n";
	      print OUT "RoiList .Current .Display2d = \"off\";\n"; 
	   };
	};
	
    close(OUT);
};
sub PlanBeamNum{
	#input Beam numbers	
	#while(1){
		#print "Plan Beam Number Choice:\n";
		#print "==================================================\n";
		#print "||    4:  Imrt4 beams;  5: Imrt5 beams;         ||\n";
		#print "||    6:  Imrt6 beams;  7: Imrt7 beams;         ||\n";
	#	print "||    8:  Imrt8 beams;  9: Imrt9 beams;         ||\n";	
	#	print "==================================================\n";
	#	print "BeamNumber=(1-9):";
	#	$Globel_BeamNum = <STDIN>;
	#	chomp($Globel_BeamNum);
	#	if($Globel_BeamNum >= 1 && $Globel_BeamNum <= 36){			
	#		last;
	#	}else{
	#		print "\nError Input: selecting 1-9.  \n\n";
	#		next;
	#	};
	#}
	#print "YouPlan will Add $Globel_BeamNum New Beam\n\n";
	$Globel_BeamNum = 9;
};
sub PlanTypeDef{
    my $PhysicanInput = ""; 	
	print "\nPlease defined Discription Dose\n";	
	foreach my $line(@Globel_TargetNameList){
		if (!defined($line) || $line =~ /^\d+/) {next;};
		while(1){			
			if($line eq "PGTV") {$PhysicanInput = 212;};			
			if($line eq "PTV1") {$PhysicanInput = 180;};
			print "$line dose is $PhysicanInput \n" if $debug;
			chomp($PhysicanInput);
			if ($PhysicanInput =~ /^\d+$/ &&  $PhysicanInput < 1200){	
				push(@Globel_Prescriptions,$line,$PhysicanInput);              #target name#target dose
				#push(@Globel_Prescriptions,$PhysicanInput);		
				last;
			}else{
				print "\nYou should Input dose(PTV=200)\n";
				next;
			};						
		};		
	};	
	#print "\nPlease defined Fraction Number\n";		
	while(1){
		print "FractionNumber\t = ";
		#$PhysicanInput = <STDIN>;
		$PhysicanInput = 33;
		print "\$PhysicanInput = $PhysicanInput\n" if $debug;
		chomp($PhysicanInput);
		if ($PhysicanInput =~ /^\d+$/ &&  $PhysicanInput < 50){				
			$Globel_FractionNum = $PhysicanInput;
			last;
		}else{
			print "\nYou should Input dose(exp 200)\n";
			next;
		};
	};	
};
sub CreateISOPoint{
    my ($FinScripFile) = @_;
	my $currenttargetname  = ();
	my $TempTargetName = undef;
	foreach $TempTargetName(@Globel_TargetNameList){
	   if (!defined($TempTargetName)){ next;};
	   if ($TempTargetName eq "PGTV"){
	       $currenttargetname = $TempTargetName;
			last;                            #point place at PTV center
		};
	};
    
    open(OUT,">>$FinScripFile") or die "unable to open $FinScripFile: $!";	
    print OUT "WindowList .CTSim .PanelList .\#\"\#1\" .GotoPanel = \"FunctionLayoutIcon1\";\n";
    print OUT "TrialList .Current .LaserLocalizer .LockJaw = \"0\";\n";
    #Ref point
    print OUT "PoiList .Current = \"POI_1\";\n";
    print OUT "PoiList .Current .Name = \"Ref.point\";\n";
    print OUT "PoiList .Current .Color = \"green\";\n";
    #Iso.center Autoplace at  center of (PGTV/PTV)
    print OUT "CreateNewPOI = \"Add Point\";\n";
    print OUT "PoiList .Current .Name = \"Iso.center\";\n";
    print OUT "PoiList .Current .Color = \"red\";\n";
    print OUT "WindowList .PoiAutoplace .Create = \"Autoplace POI...\";\n";
    print OUT "RoiList .Current = \"$currenttargetname\";\n";
    print OUT "AutoplaceCurrentPoi = \"Automatically Place Point\";\n";
    print OUT "WindowList .PoiAutoplace .Unrealize = \"Dismiss\";\n";
    close(OUT);
};
sub CreateBeams{
	my ($FinScripFile) = @_;
	my @tempGantrys = ();
	my $CurBeamGantry = "";
	
	open(OUT,">>$FinScripFile") or die "unable to open $FinScripFile: $!";
	if($Globel_BeamNum == 4) {
	   @tempGantrys = (15,165,220,335);
	}elsif($Globel_BeamNum == 5){
	   @tempGantrys = (300,0,60,140,220);
	}elsif($Globel_BeamNum == 6) {
	   @tempGantrys = (0,45,100,180,260,315);
	}elsif($Globel_BeamNum == 7){
	   @tempGantrys = (0,52,104,156,208,260,312);
	}elsif($Globel_BeamNum == 8) {
	   @tempGantrys = (30,65,100,135,225,260,295,330);
	}elsif($Globel_BeamNum == 9){
	   @tempGantrys = (0,40,80,120,160,200,240,280,320);		
	}else{
	   @tempGantrys = (0,72,144,216,288);
	   $Globel_BeamNum = 5;		
	};
	
	print OUT "WindowList .CTSim .PanelList .\#\"\#3\" .GotoPanel = \"FunctionLayoutIcon3\";\n";
	print OUT "TrialList .Current .LaserLocalizer .LockJaw = \"0\";\n";
	my $TempCnt = $Globel_BeamNum;
	while($TempCnt-- > 0){
	   print OUT "CreateNewBeam = \"Add Beam\";\n";	   
	};
	print OUT "WindowList .NewBeamSpreadsheet .Create = \"BeamSpreadsheetButton\";\n";
	print OUT "BeamLayout .Index = 0;\n";
	print OUT "BeamLayout .Index = 1;\n";
	print OUT "TrialList .Current .BeamList .\#\"*\" .Isocenter = \"Iso.center\";\n";
	$TempCnt = $Globel_BeamNum;
	while($TempCnt-- > 0){
		$CurBeamGantry = $tempGantrys[$TempCnt];
	 	chomp $CurBeamGantry;		
		print OUT "TrialList .Current .BeamList .\#\"\#$TempCnt\" .Gantry = \"$CurBeamGantry\";\n";			
	};		
	close(OUT);
};
sub DefinePrescriptionISODose{
	my ($TargetFile) = @_;
	my $temppgtvname = undef;
	my $temppgtvpres = undef;
	my $tempptvname = undef;
	my $tempptvpres = undef;
	
	
	my $tmp = 0;	
	my $TempTargetName = undef;
	
	#==============constraint for NPC
	my $TempPrescription = 212;
	my $currenttargetname = "PGTV";
	#prescription
	open (OUT,">>$TargetFile") or die "unable open file $TargetFile\n";
	print OUT "WindowList .CTSim .PanelList .\#\"\#4\" .GotoPanel = \"FunctionLayoutIcon4\";\n";
	#setting prescription dose
	print OUT "WindowList .TrialPrescription .Create = \"Edit Prescriptions...\";\n";	
	print OUT "TrialList .Current .PrescriptionList .\#\"\#0\" .MakeCurrent = 1;\n";
	print OUT "WindowList .PrescriptionEditor .Create = \"Edit...\";\n";
	print OUT "TrialList .Current .PrescriptionList .Current .PrescriptionDose = \"$TempPrescription\";\n";
	print OUT "TrialList .Current .PrescriptionList .Current .PrescriptionPercent = \"95\";\n";
	print OUT "TrialList .Current .PrescriptionList .Current .NormalizationMethod = \"ROI Mean\";\n";
	print OUT "TrialList .Current .PrescriptionList .Current .PrescriptionRoi = \"$currenttargetname\";\n";
	print OUT "TrialList .Current .PrescriptionList .Current .NumberOfFractions = \"$Globel_FractionNum\";\n";
	print OUT "WindowList .PrescriptionEditor .Unrealize = \"Dismiss\";\n";
	print OUT "WindowList .TrialPrescription .Unrealize = \"Dismiss\";\n";
	#weights
	print OUT "WindowList .BeamWeighting .Create = \"Beam Weighting...\";\n";
	print OUT "WindowList .WeightingOptions .Create = \"Weighting Options...\";\n";
	print OUT "TrialList .Current .WeightEqual = \"Set Equal Weights for Unlocked Beams\";\n";
	print OUT "WindowList .WeightingOptions .Unrealize = \"Dismiss\";\n";
	print OUT "WindowList .BeamWeighting .Unrealize = \"Dismiss\";\n";
	#Iso dose line
	print OUT "WindowList .CTSim .PanelList .\#\"\#5\" .GotoPanel = \"FunctionLayoutIcon5\";\n";
	print OUT "IsodoseControl .NormalizationMode = \"Absolute\";\n";
	print OUT "WindowList .IsodoseWindow .Create = \"Line Details...\";\n";
	
	my @linetype = ("red","purple","blue","skyblue","forest");
	$tmp = 0;		
	#foreach $TempTargetName (@curisodoseline){
	 #  print OUT "IsodoseControl .LineList .\#\"\#$tmp\" .IsoValue = \"$TempTargetName\";\n";
	#   print OUT "IsodoseControl .LineList .\#\"\#$tmp\" .Color = \"$linetype[$tmp]\";\n";
	#   $tmp = $tmp + 1;
	#};	
	print OUT "IsodoseControl .LineList .\#\"\*\" .LineWidthString = \"Medium\";\n";
	print OUT "WindowList .IsodoseWindow .Unrealize = \"Dismiss\";\n";
    print OUT "\n";	
	close(OUT);
};
sub MarkDisplayRoiDVH{
    my ($FinScripFile) = @_;
    
    #open(IN,"<$tmpROI_MODY") or die "unable to open $tmpROI_MODY: $!";
    open(OUT,">>$FinScripFile") or die "unable to open $FinScripFile: $!";
    
    print OUT "WindowList .PlanEval .CreateUnrealized = \"Dose Volume Histogram...\";\n";
    print OUT "WindowList .PlanEval .PanelList .\#\"\#0\" .GotoPanel = \"Dose Volume Histogram...\";\n";
    print OUT "WindowList .PlanEval .Create = \"Dose Volume Histogram...\";\n";
    print OUT "PluginManager .PlanEvalPlugin .TrialList .\#\"\#0\" .Selected = 1;\n";
    foreach my $line (@Globel_ROIModifyList){
		chomp($line);
		my ($linenum,$roiname,$roimark) = split(/\t/,$line);
        if ($roimark eq 'TARGET' || $roimark eq 'OAR'){
			print OUT "PluginManager .PlanEvalPlugin .ROIList .\#\"\#$linenum\" .Selected = 1;\n";
			next;
		};       
		if ($roimark eq 'CONTOURS' && ($roimark =~ /PTV(.*)/i || $roimark =~ /PGTV(.*)/i)){
			print OUT "PluginManager .PlanEvalPlugin .ROIList .\#\"\#$linenum\" .Selected = 1;\n";
			next;
		};
    };
    print OUT "DVHPlotStyle .NormalizeX = 0;\n";
    print OUT "\n";	
    close(OUT);
    #close(IN);
};
sub IMRTSetting{
	my ($TargetFile) = @_;
	my $curIMRTtargetposition = 0;	
	my ($maxitem,$doseitem,$segmentsnum) = (100,40,40); # IMRT parameters	
	
	my @templistdata = ();
	my $tempname = "";
	#my $TempTotalDose = "";
	my $tempdose = "";
	
	my $CurTargetName = "";
	my $CurTargetType = "";	
	my $CurTargetDose = "";
	my $CurTargetPerc = "";
	my $CurTargetWeight = "";
	my $CurTargetAvalue = "";
	my $CurTargetEUD = "";
	
	#for NPC 
	($maxitem,$doseitem,$segmentsnum) = (100,35,90);  
	
	open (OUT,">>$TargetFile") or die "unable open file $TargetFile\n";
	print OUT "StartIMRT = \"IPButton\";\n";
	print OUT "ImrtTemplateLayout = \"Optimization\";\n";
	print OUT "WindowList .IMRTTemplate .Create = \"IMRT Parameters...\";\n";
	print OUT "TrialList .Current .BeamList .\#\"\*\" .IMRTParameterType = \"DMPO\";\n";
	print OUT "PluginManager .InversePlanningManager .OptimizationManager .Current .TrialList .Current .MaxIterations = \"$maxitem\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current = \{\n";
	print OUT "         DoseIteration = \"$doseitem\";\n";	
	print OUT "         MaxDynamicSegments = \"$segmentsnum\";\n";	
	print OUT "         MinimumMUPerSegment = \"5\";\n";
	print OUT "         MinimumSegmentArea = \"5\";\n";
	print OUT "         ComputeFinalDose = 1;\n";
	print OUT "         \};\n";

	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#0\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#0\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#1\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#1\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#2\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#2\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#3\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#3\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#4\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#4\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#5\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#5\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#6\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#6\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#7\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#7\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#8\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#8\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#9\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#9\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#10\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#10\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#11\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#11\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#12\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#12\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#13\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#13\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#14\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#14\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#15\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#15\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#16\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#16\" .SplitBeamIfNecessary = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#17\" .AllowJawMotion = \"1\";\n";
	print OUT "PluginManager .InversePlanningManager .TrialList .Current .BeamExtensionList. \#\"\#17\" .SplitBeamIfNecessary = \"1\";\n";
	
	#target dose
	my $temp = 0;
	my $Roiexists = 0;
	$curIMRTtargetposition = 0;
		
	#Parse IMRT settings
	open(IMRTM,"<$IMRTTemplate") or die "unable to open $IMRTTemplate: $!";
	#my @TemplateData = <TEMP>;	
	while ($temp = <IMRTM>) {
	   chomp($temp);
	   if ($temp =~ /^\s*$/) {next;};
	   my @curlistdata = split(/\t/,$temp);
	   my $linelength = scalar(@curlistdata);
	   $CurTargetName = $curlistdata[0];
	   $CurTargetType = $curlistdata[1];
	   $CurTargetDose = $curlistdata[2];
	   if(($CurTargetType eq "Max DVH")||($CurTargetType eq "Min DVH")){
		   $CurTargetPerc = $curlistdata[3];
	       $CurTargetWeight = $curlistdata[4];
	   }else{
		   $CurTargetWeight = $curlistdata[3];
	   };	   
	   foreach my $line (@Globel_ROIModifyList){	#check imrt template's Roi if exists !	
		my ($linenum,$roiname,$roimark) = split(/\t/,$line);
        	if ($roimark eq $roimark ){
			$Roiexists = 1;
		};       
	   };
	   if($Roiexists){ 
	        $Roiexists=0;
	   	print OUT "PluginManager .InversePlanningManager .AddObjective = \"Add Objective\";\n";
		print OUT "PluginManager .InversePlanningManager .CombinedObjectiveList .\#\"\#$curIMRTtargetposition\" .ROIName = \"$CurTargetName\";\n";
		print OUT "PluginManager .InversePlanningManager .SetObjectiveType .\#\"\#$curIMRTtargetposition\" = \"$CurTargetType\";\n";
		print OUT "PluginManager .InversePlanningManager .CombinedObjectiveList .\#\"\#$curIMRTtargetposition\" .Dose = \"$CurTargetDose\";\n";
		if(($CurTargetType eq "Max DVH")||($CurTargetType eq "Min DVH")){
		    print OUT "PluginManager .InversePlanningManager .CombinedObjectiveList .\#\"\#$curIMRTtargetposition\" .UserPercent = \"$CurTargetPerc\";\n";
	   	};
		print OUT "PluginManager .InversePlanningManager .CombinedObjectiveList .\#\"\#$curIMRTtargetposition\" .Weight = \"$CurTargetWeight\";\n";
           };
	   $curIMRTtargetposition = $curIMRTtargetposition + 1;  
	};	
	
	#Scripts file End Mark
	print OUT "/* *H */\n";	
	close(IMRTM);
	close(OUT);
};
##:Main function Begin
my $yyyymmdd = CurTime;
if (-e $FIN_SCRIPT){
	if ($debug){
		move("$FIN_SCRIPT","/home/p3rtp/Backup/ScriptsTemp/temp/$yyyymmdd.script") ;
	}else{
		unlink($FIN_SCRIPT);
	};	
};
##:Step1  checking ROIS
ROICheck($CurPlanRoiFile,$ROIList,$FIN_SCRIPT);

##:Step2  Create Target Ring and Nomal Tissue Area 
CreatRingNT($ROIList,$ROIListModify,$FIN_SCRIPT);

##:Step3   Ask Physician input The BeamsNumber
PlanBeamNum;

##:Step4   Ask Physican Input Discription of Plan
PlanTypeDef;

##:Step5  Create Iso point which is the center of (PGTV/PTV)
#CreateISOPoint($FIN_SCRIPT);

##:Step6  Create New Beams  and setting the equal weights
#CreateBeams($BeamTemplate,$FIN_SCRIPT,$BeamNum);
CreateBeams($FIN_SCRIPT);

##:Step7  Define Prescription,ISO dose line,
DefinePrescriptionISODose($FIN_SCRIPT);

##:Step8  Mark displaying ROIs in DVH
MarkDisplayRoiDVH($FIN_SCRIPT);

##:Step9  Set IMRT Parameters and Add target and OAR doselimition 
IMRTSetting($FIN_SCRIPT);

PerlEND:print "end of programe\n";



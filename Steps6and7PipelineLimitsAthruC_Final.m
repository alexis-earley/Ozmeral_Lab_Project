clear
clc

%% --- Parameters to Change ---

%{
subjTypes = {'ONH'};
subjSettings = {'Unaided'};
%}

%{
subjTypes = {'OHI', 'OHI', 'OHI'};
subjSettings = {'Omni', 'UltraZoom', 'Unaided'};
%}


subjTypes = {'ONH', 'OHI', 'OHI', 'OHI'};
subjSettings = {'Unaided', 'Omni', 'UltraZoom', 'Unaided'};


% All of these should be in terms of volts, not microvolts:
upperThreshold = 100E-6; % 100E-6 by default/if commented out, put Inf to turn off
zScoreLimit = Inf; % 6.5 by default/if commented out, put Inf to turn off
flatStdThresh = 0; % 5E-8 by default/if commented out, put 0 to turn off
graphBool6A = 0; % Mark whether to graph individual subplots in Steps 6A - 6C
graphBool6B = 1;
graphBool6C = 1;

maxTime = 2;
timeRanges = [50 150; 150 350; 350 600];

folderName = 'Thresh_100_Only';
baseDir = 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\Final_Testing_Structs_and_Graphs';

%% Do Not Change
dirList = {};
dirNames = {};
step7CompOutDir = fullfile(baseDir, folderName, 'Step7CompareGroupsSE');
step7CompOutDiffDir = fullfile(baseDir, folderName, 'Step7CompareGroupsSE_diff');
%{
step7CompOutDir = fullfile(baseDir, folderName, 'Step7CompareGroupsSE_filt');
step7CompOutDiffDir = fullfile(baseDir, folderName, 'Step7CompareGroupsSE_diff_filt');
%}
step7BoxOutDir = fullfile(baseDir, folderName, 'Step7CompareBoxPlots');

for i = 1:length(subjSettings)     
    subjType = subjTypes{i}; % Ex. ONH
    subjSetting = subjSettings{i}; % Ex. Unaided
    
    step6AInDir = fullfile(baseDir, 'Step6A_Input', subjType, subjSetting);
    step6ACBaseDir = fullfile(baseDir, folderName); % Subfolders are below in function def.
    step6AOutDir = fullfile(baseDir, folderName, 'Step6A_Output', subjType, subjSetting);
    step6BOutDir = fullfile(baseDir, folderName, 'Step6B_Output', subjType, subjSetting);
    step6COutDir = fullfile(baseDir, folderName, 'Step6C_Output', subjType, subjSetting);
    step6C2OutDir = fullfile(baseDir, folderName, 'Step6C2_Output', subjType, subjSetting);
    %step6DPOutDir = fullfile(baseDir, folderName, 'Step6DP_Output', subjType, subjSetting);
    %step6DOutDir = fullfile(baseDir, folderName, 'Step6D_Output', subjType, subjSetting);
    step6DOutDir = fullfile(baseDir, folderName, 'Step6D_Output', subjType, subjSetting);
    %step6EOutDir = fullfile(baseDir, folderName, 'Step6E__Output', subjType, subjSetting);
    step6EOutDir = fullfile(baseDir, folderName, 'Step6E_Sep_Output', subjType, subjSetting);
    %step6FOutDir = fullfile(baseDir, folderName, 'Step6F_Output', subjType, subjSetting);
    step6FOutDir = fullfile(baseDir, folderName, 'Step6F_Sep_Output', subjType, subjSetting);
    step6GOutDir = fullfile(baseDir, folderName, 'Step6G_Sep_Output', subjType, subjSetting);
    step7AOutDir= fullfile(baseDir, folderName, 'Step7_Graph_All_Output', subjType, subjSetting);
    step7BOutDir= fullfile(baseDir, folderName, 'Step7_Graph_Subjects_Output', subjType, subjSetting);
    step7COutDir= fullfile(baseDir, folderName, 'Step7_Graph_GFPs_Output', subjType, subjSetting);
    step7DOutDir= fullfile(baseDir, folderName, 'Step7_Graph_Peaks_Output', subjType, subjSetting);
    step7EOutDir= fullfile(baseDir, folderName, 'Step7_Make_Peak_Table_Output', subjType, subjSetting);
    step7FOutDir= fullfile(baseDir, folderName, 'Step7_Graph_GFP_Blocks_Output', subjType, subjSetting);
    step7GTitle = [subjType, ' ', subjSetting, ' - ', folderName];
     
    peakValsFolder = 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\Final_Testing_Structs_and_Graphs\Step6AA_Output\ONH\Unaided';
    
    %{
    %% Step 6AA
    disp('Starting Step 6AA:'); tic;
    Step6AAPeakDiffs(step6AInDir, peakValsFolder);
    disp(['Step 6AA completed in ', num2str(toc/60), ' minutes.']);
    %}

    %% Step 6A through 6C
    disp('Starting Step 6A thru 6C:'); tic;
    Step6OutDirs = {step6AOutDir, step6BOutDir, step6COutDir};
    Step6AthruC(step6AInDir, Step6OutDirs, step6ACBaseDir, fullfile(subjType, subjSetting), graphBool6A, graphBool6B, graphBool6C, upperThreshold, zScoreLimit, flatStdThresh);
    %Step6AthruCPercent(step6AInDir, peakValsFolder, step6ACBaseDir, fullfile(subjType, subjSetting), [0.05, 0.95]);
    disp(['Step 6A thru 6C completed in ', num2str(toc/60), ' minutes.']);

%{
     %% Step 6C2 - Combine Blocks
    disp('Starting Step 6C2 - Combine Blocks:'); tic;
    Step6CNew2CombinedBlocks(step6BOutDir, step6C2OutDir)
    disp(['Step 6C2 - Combine Blocks completed in ', num2str(toc/60), ' minutes.']);
    %{
    %% Step 6D Seperate Prequel
    disp('Starting Step 6D Prequel:'); tic;
    Step6D_Sep_Prequel(step6COutDir, step6DPOutDir, 25, 25);
    disp(['Step 6D Prequel completed in ', num2str(toc/60), ' minutes.']);
    %}

    %% Step 6D
    
    disp('Starting Step 6D:'); tic;
    Step6DNew2(step6COutDir, step6DOutDir);
    disp(['Step 6D completed in ', num2str(toc/60), ' minutes.']);
    
    %{
    %% Step 6E - Old
    disp('Starting Step 6E:'); tic;
    Step6ECombineActiveLR(step6DOutDir, step6EOutDir);
    disp(['Step 6E completed in ', num2str(toc/60), ' minutes.']);
    %}
    
    %% Step 6E Seperate
    disp('Starting Step 6E:'); tic;
    Step6ECombineActiveLR2(step6COutDir, step6EOutDir);
    disp(['Step 6E completed in ', num2str(toc/60), ' minutes.']);

    %% Step 6F Seperate
    disp('Starting Step 6F:'); tic;
    %Step6F2(step6EOutDir, step6FOutDir);
    Step6F2(step6EOutDir, step6FOutDir);
    disp(['Step 6F completed in ', num2str(toc/60), ' minutes.']);

    %{
    %% Step 6G Combine All (Only to Check)
    disp('Starting Step 6G:'); tic;
    Step6GWeightedAverageAll(step6FOutDir, step6GOutDir);
    disp(['Step 6G completed in ', num2str(toc/60), ' minutes.']);
    %}

    %% Step 7A - Graph All    
    disp('Starting Step 7 - Graph All:'); tic;
    Step7GraphAll2(step6DOutDir, step7AOutDir, step7GTitle);
    disp(['Step 7 - Graph All completed in ', num2str(toc), ' seconds.']);
    
    %% Step 7B - Graph Subjects    
    disp('Starting Step 7 - Graph Subjects:'); tic;
    Step7GraphSubjects2(step6EOutDir, step7BOutDir, step7GTitle);
    disp(['Step 7 - Graph Subjects completed in ', num2str(toc), ' seconds.']);
   
    %% Step 7C - Graph GFPs   
    disp('Starting Step 7 - Graph GFPs:'); tic;
    Step7GraphGFPAllSubjects(step6FOutDir, step7COutDir, timeRanges, maxTime)
    disp(['Step 7 - Graph GFPs completed in ', num2str(toc), ' seconds.']);    

    %% Step 7D - Graph Peaks
    disp('Starting Step 7 - Graph Peaks:'); tic;
    Step7GraphPeaks(step6FOutDir, step7DOutDir, timeRanges, step7GTitle);
    disp(['Step 7 - Graph Peaks completed in ', num2str(toc), ' seconds.']);

    %% Step 7E - Make Peak Table
    disp('Starting Step 7 - Make Peak Table:'); tic;
    Step7MakePeakTable(step6FOutDir, step7EOutDir, timeRanges);
    disp(['Step 7 - Make Peak Table completed in ', num2str(toc), ' seconds.']);

    %% Step 7F - Graph GFP Blocks Overlay
    disp('Starting Step 7 - Graph GFP Blocks Overlay:'); tic;
    Step7GraphGFP_6C2Overlay(step6C2OutDir,  step7FOutDir, maxTime)
    disp(['Step 7 - Graph GFP Blocks Overlay completed in ', num2str(toc), ' seconds.']);

    %% Step 7 All Subject Types - Setup
    dirList{end+1} = step6FOutDir;
    dirNames{end+1} = [subjType, ' ', subjSetting];

%}
end

%{
%% Step 7 All Subject Types
Step7CompareGroupsSE(dirList, dirNames, [1, 4; 2, 3], step7CompOutDiffDir, maxTime)
Step7BoxplotCompGFP(dirList, dirNames, step7BoxOutDir);
%}

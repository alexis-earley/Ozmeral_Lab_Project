%% Change variables below

% Set up
clear;
clc;
sFiles = [];

% State whether this is a new experiment
NewExperiment = true;

% If not starting a new experiment, state which file to load variables from
% Note this can be an output file or just a list of sfiles from Brainstorm

LoadFile = '2024_2025_Paper_All_Subjects_Step_0.mat';
if ~NewExperiment
    load(LoadFile)
end

script_new;

% State which file to output variables to
SaveFile = '2024_2025_Paper_All_Subjects_Step_1.mat';

% Insert step to start at here (must be 0 for a new experiment)
FirstStep = 1;
% Insert step to end at here (cannot be less than previous step)
LastStep = 1;

% If running Steps 0 or 5, insert subjects of interest here
SubjectNums = {'0170', '1009', '1031', '1068', '1071','1081', '1111', ...
    '1113', '1145', '1153', '1157', '1191', '1223', '1228', '1263', ...
    '1264', '1273', '1337'};

% If running Step 3, insert path of protocol used
ProtocolPath = '/Users/alexis/Documents/Brainstorm/brainstorm_db/SAA_Test_All_Subjects/data';

% If running Step 4, insert order file
FullTable = ('Full_Table_09_17_24.csv');

%%  Do not change from now on

% Start a new report
bst_report('Start', sFiles);

% Run desired functions

% Set up subjects and channel files
if FirstStep == 0 && LastStep >= 0 
    sFiles = SetUpSubjects(sFiles,SubjectNums);
end

% Do filtering
if FirstStep <= 1 && LastStep >= 1 
    sFiles = Step1(sFiles);
end

% Remove artifacts
if FirstStep <= 2 && LastStep >= 2
    sFiles = Step2(sFiles);
end

% Split based on channels
if FirstStep <= 3 && LastStep >= 3 
    sFiles = Step3(sFiles);
    sFiles = DeleteShortTimes(sFiles, ProtocolPath);
end

% Epoch and sort by condition
if FirstStep <= 4 && LastStep >= 4 
    sFiles = Step4(sFiles, FullTable);
end

 % Average
if FirstStep <= 5 && LastStep >= 5
    sFiles = Step5(sFiles, SubjectNums);
end

% Save variables
save(SaveFile);

% Save and display report
ReportFile = bst_report('Save', sFiles);
bst_report('Open', ReportFile);
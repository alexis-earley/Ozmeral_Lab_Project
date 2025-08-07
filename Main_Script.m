clearvars -except sFiles;
clc;

% Runs the main Brainstorm pipeline (whichever steps user wants)

% ======================== SET GLOBAL VARIABLES ===========================
% CHANGE AS NEEDED:

selectNewFiles = false; % Will disregard if no sFiles exist in Workspace yet

protocolName = 'Paper_Data_OHI_01_27_2025'; % Will desregard if a protocol is already open

subjectNums = {'0941','0982','0994','1024','1057','1109', ...
    '1136','1172','1233','1257','1372','1168'};

% =============================== SET UP =================================
% DO NOT CHANGE:

% Open Brainstorm and load current protocol, if not done already
setUpBrainstorm(protocolName);

if ~exist(sFiles, 'var')
    selectNewFiles = true;
end

if selectNewFiles
    sFiles = SelectFiles();
end

sFilesNew = {};
for i = 1:length(subjectNums)
    subjectNum = subjectNums{i};
    sFilesNew = [sFilesNew, Select_Using_Tags(sFiles, subjectNum)];
end
sFiles = sFilesNew;

% Start a new report
bst_report('Start', sFiles);

% =============================== STEP 0 =================================
% DO NOT CHANGE:

% Set up subjects and channel files
sFiles = SetUpSubjects(sFiles,SubjectNums);

% =============================== STEP 1 =================================
% DO NOT CHANGE:

% Do filtering
sFiles = Step1(sFiles);

% =============================== STEP 2 =================================
% DO NOT CHANGE:

% Remove artifacts
sFiles = Step2(sFiles);

% =============================== STEP 3 =================================
% CHANGE AS NEEDED:

% Insert path of protocol used (should end with data folder)
ProtocolPath = 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\Brainstorm_db\Paper_Data_OHI_01_27_2025\data';

% Insert minimum number of milliseconds for files (default = 350)
minTime = 350;

% ------------------------------------------------------------------------

% DO NOT CHANGE:

% Split based on channels
sFiles = Step3_New(sFiles);

sFiles = DeleteShortTimes(sFiles, ProtocolPath, minTime);

% =============================== STEP 4 =================================
% CHANGE AS NEEDED:

% Insert order file
fullTable = ('Full_Table_09_17_24.csv');

% ------------------------------------------------------------------------

% DO NOT CHANGE:

% Epoch and sort by condition
if FirstStep <= 4 && LastStep >= 4 
    sFiles = Step4(sFiles, fullTable);
end

% =============================== STEP 5 =================================
% CHANGE AS NEEDED:
protocolPath5 = 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\Data_Structs\All_Subjects\';

% ------------------------------------------------------------------------

% DO NOT CHANGE:
disp('Starting Step 5:')

gSubjectNames = cellfun(@(x) ['Subject_', x], subjectNums, ...
    'UniformOutput', false); % Add 'Subject_' in front of each subject number

if selectNewFiles
    sFiles = Select_Using_Tag(sFiles, 'Epochs');
end

sFilesFinal = {};
for i = 1:length(gSubjectNames)
    subject_name = gSubjectNames(i);
    disp(['Converting ', char(subject_name), ' to struct form.']);
    sFiles_5_subj = Select_Using_Tag(sFiles_5, subject_name);
    Step5_New(sFiles_5_subj, protocolPath5);
    sFilesFinal{end + 1} = sFiles_5_subj;
end

% =============================== WRAP UP =================================
% DO NOT CHANGE:

% Save and display report
ReportFile = bst_report('Save', sFilesFinal);
bst_report('Open', ReportFile);


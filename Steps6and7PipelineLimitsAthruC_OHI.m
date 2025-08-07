clear
clc

subTypes = {'Omni', 'UltraZoom', 'Unaided'};

for i = 1:length(subTypes)
%% Parameters to Change

% All of these should be in terms of volts, not microvolts:
upperThreshold = 100E-6; % 100E-6 by default/if commented out, put Inf to turn off
zScoreLimit = 6.5; % 6.5 by default/if commented out, put Inf to turn off
flatStdThresh = 5E-8; % 5E-8 by default/if commented out, put 0 to turn off
graphBool = 0; % Mark whether to graph individual subplots in Steps 6A - 6C

%% Folder Names to Change

folderName = 'Default_Parameters';
baseDir = 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\Final_Testing_Structs_and_Graphs';
subjType = 'OHI';
subType = subTypes{i};

%% Folder Names Not to Change

step6AInDir = fullfile(baseDir, subjType, 'Step6A_Input', subType);
step6ACBaseDir = fullfile(baseDir, subjType, folderName); % Subfolder is in function definition
step6COutDir = fullfile(baseDir, subjType, folderName, 'Step6C_Output', subType);
step6DOutDir = fullfile(baseDir, subjType, folderName, 'Step6D_Output', subType);
step6EOutDir = fullfile(baseDir, subjType, folderName, 'Step6E_Output', subType);
step7AOutDir= fullfile(baseDir, subjType, folderName, 'Step7_Graph_All_Output', subType);
step7BOutDir= fullfile(baseDir, subjType, folderName, 'Step7_Graph_Subjects_Output', subType);
step7GTitle = [subjType, ' ', subType, ' - ', folderName];

%{
%% Step 6A through 6C
disp('Starting Step 6:'); tic;
Step6AthruC(step6AInDir, step6ACBaseDir, subType, graphBool, upperThreshold, zScoreLimit, flatStdThresh);
disp(['Step 6 completed in ', num2str(toc/60), ' minutes.']);

%% Step 6D

disp('Starting Step 6D:'); tic;
Step6DNew2(step6COutDir, step6DOutDir);
disp(['Step 6D completed in ', num2str(toc/60), ' minutes.']);
%}
%% Step 6E

disp('Starting Step 6E:'); tic;
Step6E_CombineActiveLR(step6DOutDir, step6EOutDir);
disp(['Step 6E completed in ', num2str(toc/60), ' minutes.']);

%% Step 7A - Graph All

disp('Starting Step 7 - Graph All:'); tic;
Step7GraphAll2(step6EOutDir, step7AOutDir, step7GTitle);
disp(['Step 7 - Graph All completed in ', num2str(toc), ' seconds.']);
%{
%% Step 7B - Graph Subjects

disp('Starting Step 7 - Graph Subjects:'); tic;
Step7GraphSubjects2(step6COutDir, step7BOutDir, step7GTitle);
disp(['Step 7 - Graph Subjects completed in ', num2str(toc), ' seconds.']);

%}
end

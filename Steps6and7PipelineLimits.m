clear
clc

% CHANGE:
channelLimit = 100;
step6BaseDir = 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\ONH_Data_Structs';
subfolder6 = '\Unaided';
tag6 = '_New_Step6_Only_Peak_Param'; % Set to '' or start with underscore!

% DO NOT CHANGE:
step6AInDir = fullfile(step6BaseDir, '\New_Pipeline\Step_6A_Input', subfolder6);
step6AOutDir = fullfile(step6BaseDir, ['\Testing_Limits\Test_', num2str(channelLimit), '_Limit\Step6A_Output', tag6], subfolder6);
step6BOutDir = fullfile(step6BaseDir, ['\Testing_Limits\Test_', num2str(channelLimit), '_Limit\Step6B_Output', tag6], subfolder6);
step6COutDir = fullfile(step6BaseDir, ['\Testing_Limits\Test_', num2str(channelLimit), '_Limit\Step6C_Output', tag6], subfolder6);
step6DOutDir = fullfile(step6BaseDir, ['\Testing_Limits\Test_', num2str(channelLimit), '_Limit\Step6D_Output', tag6], subfolder6);

% CHANGE:
step7BaseDir = ['E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\Result_Graphs\Test_', num2str(channelLimit), '_Limit'];
subfolder7 = '\ONH\Unaided';
tag7 = tag6;

% DO NOT CHANGE:
step7GAllOutDir = fullfile(step7BaseDir, ['\Step_7_Graph_All', tag7], subfolder7);
step7GSubjsOutDir = fullfile(step7BaseDir, ['\Step_7_Graph_Subjects', tag7], subfolder7);
step7GTitle = ['ONH ', num2str(channelLimit), ' µV Limit - Test', tag7];

%% Step 6A
disp('Starting Step 6A:');
tic;
Step6New3(step6AInDir, step6AOutDir, channelLimit);
disp(['Step 6A completed in ', num2str(toc/60), ' minutes.']);

%% Step 6B
disp('Starting Step 6B:');
tic;
Step6BNew2(step6AOutDir, step6BOutDir);
disp(['Step 6B completed in ', num2str(toc/60), ' minutes.']);

%% Step 6C
disp('Starting Step 6C:');
tic;
Step6CNew2(step6BOutDir, step6COutDir);
disp(['Step 6C completed in ', num2str(toc/60), ' minutes.']);

%% Step 6D
disp('Starting Step 6D:');
tic;
Step6DNew2(step6COutDir, step6DOutDir);
disp(['Step 6D completed in ', num2str(toc/60), ' minutes.']);

%% Step 7
disp('Starting Step 7 - Graph All:');
tic;
Step7GraphAll2(step6DOutDir, step7GAllOutDir, step7GTitle);
disp(['Step 7 - Graph All completed in ', num2str(toc), ' seconds.']);

disp('Starting Step 7 - Graph Subjects:');
tic;
Step7GraphSubjects2(step6COutDir, step7GSubjsOutDir, step7GTitle);
disp(['Step 7 - Graph Subjects completed in ', num2str(toc), '
seconds.']);
%}
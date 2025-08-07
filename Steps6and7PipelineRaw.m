clear
clc

step6BaseDir = 'E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\ONH_Data_Structs';
subfolder6 = '\Unaided';
step6AInDir = '';
step6AOutDir = '';
step6BOutDir = '';
step6COutDir = fullfile(step6BaseDir,'\New_Pipeline\Step_6C_Output_New', subfolder6);
step6DOutDir = fullfile(step6BaseDir,'\New_Pipeline\Step_6D_Output_New', subfolder6);

step7BaseDir = ['E:\Alexis_Brainstorm\EOR21_Earley_Paper_Final\Result_Graphs\Raw_Graphs'];
subfolder7 = '\ONH\Unaided';
step7GAllOutDir = fullfile(step7BaseDir, '\Step_7_Graph_All', subfolder7);
step7GSubjsOutDir = fullfile(step7BaseDir, '\Step_7_Graph_Subjects', subfolder7);
step7GTitle = ['ONH Raw'];

%{
%% Step 6A
disp('Starting Step 6A:');
Step6ANew2(step6AInDir, step6AOutDir, channelLimit);

%% Step 6B
disp('Starting Step 6B:');
Step6BNew2(step6AOutDir, step6BOutDir);

%% Step 6C
disp('Starting Step 6C:');
Step6CNew2(step6BOutDir, step6COutDir);

%% Step 6D
disp('Starting Step 6D:');
Step6DNew2(step6COutDir, step6DOutDir);
%}

%% Step 7
disp('Starting Step 7 - Graph All:');
Step7GraphAll(step6DOutDir, step7GAllOutDir, step7GTitle);

disp('Starting Step 7 - Graph Subjects:');
Step7GraphSubjects(step6COutDir, step7GSubjsOutDir, step7GTitle);
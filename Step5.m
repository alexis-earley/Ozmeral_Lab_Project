function sFiles = Step5(sFiles, SubjectNums)

    Conditions ={'Noise_Attend30','Quiet_Passive', 'Noise_Passive', 'Noise_Attend60'};
    
    ActiveTags = {
        {'2_Y', '12_Y', '17_Y', '22_Y'}, ...
        {'2_N', '12_N', '17_N', '22_N'}, ...
        {'3_Y', '8_Y', '18_Y', '23_Y'}, ...
        {'3_N', '8_N', '18_N', '23_N'}, ...
        {'4_Y', '9_Y', '14_Y', '24_Y'}, ...
        {'4_N', '9_N', '14_N', '24_N'}, ...
        {'5_Y', '10_Y', '15_Y', '20_Y'}, ...
        {'5_N', '10_N', '15_N', '20_N'}...
        {'6_Y', '11_Y', '16_Y', '21_Y'}, ...
        {'6_N', '11_N', '16_N', '21_N'}, ...
        };

    ActiveNames = {
        {'2/12/17/22_Y'}, ...
        {'2/12/17/22_N'}, ...
        {'3/8/18/23_Y'}, ...
        {'3/8/18/23_N'}, ...
        {'4/9/14/24_Y'}, ...
        {'4/9/14/24_N'}, ...
        {'5/1/15/20_Y'}, ...
        {'5/1/15/20_N'} ...
        {'6/11/16/21_Y'}, ...
        {'6/11/16/21_N'}, ...
        };
    
    PassiveTags = {
        {'2', '12', '17', '22'}, ...
        {'3', '8', '18', '23'}, ...
        {'4', '9', '14', '24'}, ...
        {'5', '10', '15', '20'} ...
        {'6', '11', '16', '21'}, ...
        };

    PassiveNames = {
        {'2/12/17/22'}, ...
        {'3/8/18/23'}, ...
        {'4/9/14/24'}, ...
        {'5/1/15/20'}, ...
        {'6/11/16/21'}, ...
        };
    
    SubjectNames = {};
    AddedFiles = [];
    
    for i = 1:length(SubjectNums)
        SubjectNum = SubjectNums(i);
        WholeName = strcat('Subject_', SubjectNum);
        SubjectNames = [SubjectNames, WholeName];
    end
    
    for i = 1:length(SubjectNames)
    
        SubjectName = SubjectNames{i};

        % Process: Select file paths with tag: Subject Name
        sFileName = bst_process('CallProcess', 'process_select_tag', sFiles, [], ...
            'tag',    SubjectName, ...
            'search', 1, ...  % Search the file paths
            'select', 1);  % Select only the files with the tag
    
        for j = 1:length(Conditions)
    
            Condition = Conditions{j};
    
            if (Condition == "Quiet_Passive") || (Condition == "NoisePassive")
                Active = false;
                Tags = PassiveTags;
                TagNames = PassiveNames;
            else
                Active = true;
                Tags = ActiveTags;
                TagNames = ActiveNames;
            end

            
            % Process: Select file paths with condiition: ex. Noise_Attend30
            sFileCondition = bst_process('CallProcess', 'process_select_tag', sFileName, [], ...
                'tag',    Condition, ...
                'search', 1, ...  % Search the file paths
                'select', 1);  % Select only the files with the tag
    
            for k = 1:length(Tags)
    
                TagGroup = Tags{k};
                TagName = TagNames{k};

                sFileTemp = [];

                for l = 1:length(TagGroup)

                    Tag = TagGroup{l};

                   % Process: Select file names with tag, ex. 2_Y
                   sFileTag = bst_process('CallProcess', 'process_select_tag', sFileCondition, [], ...
                    'tag',    Tag, ...
                    'search', 2, ...  % Search the file names
                    'select', 1);  % Select only the files with the tag

                   sFileTemp = [sFileTemp, sFileTag];

                end

                sFile = sFileTemp;

                %{

                if Active && (~isnan(str2double(Tag)))
    
                    % Process: Ignore file names with tag: _Y
                    sFile = bst_process('CallProcess', 'process_select_tag', sFile, [], ...
                        'tag',    '_Y', ...
                        'search', 2, ...  % Search the file names
                        'select', 2);  % Ignore the files with the tag
    
                    % Process: Ignore file names with tag: _N
                    sFile = bst_process('CallProcess', 'process_select_tag', sFile, [], ...
                        'tag',    '_N', ...
                        'search', 2, ...  % Search the file names
                        'select', 2);  % Ignore the files with the tag
                end

                %}
                
                NumFiles = length(sFile);
                NewName = [char(SubjectName), '_', char(Condition), '_', char(TagName), '_Average_', num2str(NumFiles), '_files'];

                % Process: Average: Everything
                sFile = bst_process('CallProcess', 'process_average', sFile, [], ...
                    'avgtype',       1, ...  % Everything
                    'avg_func',      1, ...  % Arithmetic average:  mean(x)
                    'weighted',      0, ...
                    'keepevents',    0);
    
                % Process: Set name
                sFile = bst_process('CallProcess', 'process_set_comment', sFile, [], ...
                    'tag',           NewName, ...
                    'isindex',       1);
                
                % Process: Move files: Subject_Name/Averages
                sFile = bst_process('CallProcess', 'process_movefile', sFile, [], ...
                    'subjectname', SubjectName, ...
                    'folder',      'Averages');

                AddedFiles = [AddedFiles, sFile];
                
            end
        end
    end

    sFiles = [sFiles, AddedFiles];
end

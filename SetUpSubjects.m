function sFiles = SetUpSubjects(sFiles,SubjectNums)

%Set up local variables
SubjectNames = {};

    for i = 1:length(SubjectNums)
    
        RawFiles = {};
        sFileIndiv = [];
        CurrSubject = SubjectNums{i};
        SubjectName = strcat('Subject_',CurrSubject);
        SubjectNames = [SubjectNames, SubjectName];
        FileName = strcat (CurrSubject, '/EOR21_Aim1_', CurrSubject, '*.cnt');
        FileList= dir(FileName);
        RawFiles = [RawFiles, strcat({FileList.folder}', '/', {FileList.name}')];

        ChannelFile = strcat (CurrSubject, '/Subject_', CurrSubject, '*.pos');
        ChannelFileList = dir(ChannelFile);
        ChannelFiles = strcat({ChannelFileList.folder}', '/', {ChannelFileList.name}');
    
        for j = 1:length(RawFiles)
    
            CurrRawFile = RawFiles{j};
            %disp(CurrRawFile);
    
            % Process: Create link to raw file
            sFileIndiv = bst_process('CallProcess', 'process_import_data_raw', sFileIndiv, [], ...
                'subjectname',    SubjectNames{i}, ...
                'datafile',       {CurrRawFile, 'EEG-ANT-CNT'}, ...
                'channelreplace', 0, ...
                'channelalign',   1, ...
                'evtmode',        'value');
    
            RawNums = regexp(CurrRawFile,'[0-9]','match');
            RawNums = [RawNums(1:4), RawNums(8:19)];
    
            foundChannel = 0;
    
            for k = 1:length(ChannelFiles)
                CurrChannelFile = ChannelFiles{k};
                ChannelNums = regexp(CurrChannelFile,'[0-9]','match');
                ChannelNums = ChannelNums(1:16);
                
                if isequal(RawNums,ChannelNums)
    
                    sFileIndiv = bst_process('CallProcess', 'process_channel_addloc', sFileIndiv, [], ...
                    'channelfile', {CurrChannelFile, 'POLHEMUS'}, ...
                    'usedefault',  'Colin27: ANT Waveguard 64', ...  
                    'fixunits',    1, ...
                    'vox2ras',     0, ...
                    'mrifile',     {'', ''}, ...
                    'fiducials',   []);
                    foundChannel = 1;
                    break;
                end
            end
            
            if foundChannel == 0
                disp('Error: No channel file found');
            end

            sFiles = [sFiles, sFileIndiv];
            
        end
    end

    

    sFiles = bst_process('CallProcess', 'process_channel_setbad', sFiles, [], ...
    'sensortypes', ['EOG, BIP1, BIP2, BIP3, BIP4, BIP5, BIP6, BIP7, BIP8, BIP9, ...' ...
    'BIP10, BIP11, BIP12, BIP13, BIP14, BIP15, BIP16, BIP17, BIP18, BIP19, ...' ...
    'BIP20, BIP21, BIP22, BIP23, BIP24, GRS1, RESP1, TEMP1, ACC1']);

end




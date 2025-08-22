function includeBool = IncludeTrigger(condition, trigger, removeDiags, removeNos)
% Note for include Bool:
% 1 = include
% 0 = do not include because incorrect (attend)
% -1 = do not include due to parameters (attend or passive)

% TO DO: change to better return policy - based on strings?
% Y = Yes, include
% AI = No, active and incorrect
% AR = No, active parameter restriction
% PR = No, passive parameter restriction

% See if this is an active condition
isActiveCond = strncmp(condition, 'Attend', 6);

% Split up condition
condLabel = condition(7:end);
trigParts = split(trigger, '_');
triggerNum = trigParts{2};
if isActiveCond
    triggerTag = trigParts{3};
end

% If Passive:
if ~isActiveCond
    if ~removeDiags && ~removeNos % keep both
        includeBool = 1;
        return
    end

    if removeDiags && removeNos % remove both
        passNums = [3, 8, 18, 23];
    elseif ~removeDiags && removeNos % remove nos and keep diags
        passNums = [3, 8, 13, 18, 23];
    elseif removeDiags && ~removeNos % keep nos and remove diags
        passNums = setdiff(1:25, [1, 7, 13, 19, 25]);
    end

    if ismember(str2double(triggerNum), passNums)
        includeBool = 1;
        return
    else
        includeBool = -1;
        return
    end
end

% If Active:
%           To 60L: To 30L: To 0:   To 30R: To 60R:         
% From 60L: 1       2       3       4       5
% From 30L: 6       7       8       9       10
% From 0:   11      12      13      14      15
% From 30R: 16      17      18      19      20
% From 60R: 21      22      23      24      25

locMatrix = reshape(1:25, [5, 5])'; 
locLabels = {'60L', '30L', '0', '30R', '60R'}; % Column titles

if removeNos
    if triggerTag == 'N'; includeBool = -1; return; end
end

if removeDiags
    diags = [1, 7, 13, 19, 25];
    if ismember(str2double(triggerNum), diags)
        includeBool = -1; return;
    end
end

% Find the column number of this trigger in the location matrix
[~, locIdx] = find(locMatrix == str2double(triggerNum)); % Ex. 5 for trigger 25
soundLoc = locLabels{locIdx}; % Ex. sound was at location 30R

if soundLoc == condLabel
    if triggerTag == 'Y'; includeBool = 1; return;
    elseif triggerTag == 'N'; includeBool = 0; return;
    end
else
    if triggerTag == 'Y'; includeBool = 0; return;
    elseif triggerTag == 'N'; includeBool = 1; return;
    end
end

end
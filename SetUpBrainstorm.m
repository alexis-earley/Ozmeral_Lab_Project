function SetUpBrainstorm(protocol_name)

addpath 'C:\Users\aearley1\Desktop\Brainstorm\brainstorm3'
if ~brainstorm('status')
    brainstorm
end

currentProtocol = bst_get('ProtocolInfo');
if ~strcmp(currentProtocol.Comment, protocol_name)
    iProtocol = bst_get('Protocol', protocol_name);
    gui_brainstorm('SetCurrentProtocol', iProtocol);
end

end


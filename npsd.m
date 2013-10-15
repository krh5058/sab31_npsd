function npsd
% NPSD
% As requested by Adriene Beltz & Sheri Berenbaum
% 6/15/13
%
% Author: Ken Hwang
% SLEIC, PSU

if ~ispc
    error('npsd.m:PC support only.')
end

% Directory initialization
try
    fprintf('npsd.m: Directory initialization...\n')
    
    mainpath = which('main.m');
    if ~isempty(mainpath)
        [mainext,~,~] = fileparts(mainpath);
        rmpath(mainext);
    end
    
    javauipath = which('javaui.m');
    if ~isempty(javauipath)
        [javauiext,~,~] = fileparts(javauipath);
        rmpath(javauiext);
    end
    
    p = mfilename('fullpath');
    [ext,~,~] = fileparts(p);
    [~,d] = system(['dir /ad-h/b ' ext]);
    d = regexp(strtrim(d),'\n','split');
    cellfun(@(y)(addpath([ext filesep y])),d);
    fprintf('npsd.m: Directory initialization success!.\n')
catch ME
    throw(ME)
end

try
    fprintf('npsd.m: Object Handling...\n')
    % Object construction and event handling
    obj = main(ext,d);
    pobj = pres(obj);
    obj.addl(pobj);
    fprintf('npsd.m: Object Handling success!.\n')
catch ME
    throw(ME)
end

try
    fprintf('npsd.m: Window initialization...\n')
    % Open and format window
    obj.monitor.w = Screen('OpenWindow',obj.monitor.whichScreen,obj.monitor.black);
    Screen('BlendFunction',obj.monitor.w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('TextSize',obj.monitor.w,obj.exp.textsize);
    fprintf('npsd.m: Window initialization success!.\n')
catch ME
    throw(ME)
end

fprintf('npsd.m: Beginning presentation sequence...\n')
ListenChar(2);
HideCursor;
ShowHideWinTaskbarMex(0);

% Wait for instructions
RestrictKeysForKbCheck([obj.exp.keys.spacekey obj.exp.keys.esckey obj.exp.keys.key1 obj.exp.keys.key2 obj.exp.keys.key3 obj.exp.keys.key4]);
obj.dat.txt = obj.exp.intro1;
notify(obj,'txt');
[~,keyCode] = KbStrokeWait;

if (find(keyCode)==obj.exp.keys.esckey)
    obj.abort = 1;
end

if obj.abort
else
    obj.dat.txt = obj.exp.intro2;
    notify(obj,'txt');
    [~,keyCode] = KbStrokeWait;
    
    if (find(keyCode)==obj.exp.keys.esckey)
        obj.abort = 1;
    end
end

if obj.abort
else
    obj.dat.txt = obj.exp.wait;
    notify(obj,'txt');
    
    for i = obj.exp.order
        
        % Triggering
        if obj.exp.trig % Auto-trigger
            RestrictKeysForKbCheck(obj.exp.keys.tkey);
            KbStrokeWait; % Waiting for first trigger pulse
        else % Manual trigger
            RestrictKeysForKbCheck(obj.exp.keys.spacekey);
            KbStrokeWait; % Waiting for scanner operator
            obj.dat.txt = obj.exp.wait2;
            notify(obj,'txt');
            pause(obj.exp.DisDaq); % Simulating DisDaq
        end
        
        RestrictKeysForKbCheck([obj.exp.keys.esckey obj.exp.keys.key1 obj.exp.keys.key2 obj.exp.keys.key3 obj.exp.keys.key4]);
        obj.cycle(i);
        
        if obj.abort
            break;
        end
        
    end
end

% Clean up
ListenChar(0);
ShowCursor; 
ShowHideWinTaskbarMex(1);
Screen('Preference','VisualDebugLevel',obj.monitor.oldVisualDebugLevel);
fclose('all');
Screen('CloseAll');

end
%% KKT Constraint Class
% container to hold KKT attributions for one constaint
%

%%
classdef KKTCons < handle
    properties (Constant)
        KKT_SIDE_DEFAULT = 0;
        KKT_UPSIDE = 1;
        KKT_DOWNSIDE = -1;	
    end
    
    properties 
        displayName;
        constraintID;
        isPenalty;
        upOrDownside; 
        weights;
    end
	
    methods
        function self = KKTCons(term, id, title, side, pen)
            self.constraintID = id;
            self.displayName = title;
            self.isPenalty = pen;
            self.upOrDownside = side;
            self.weights = containers.Map;
            
            idset = term.GetKeySet();
            asset = idset.GetFirst();
            while ~strcmp(asset,'')
                self.weights(char(asset)) = term.GetValue(asset);
                asset = idset.GetNext();
            end
        end
        function ret = Contains(self, id)
            ret = self.weights.isKey(char(id)); 
        end
        function val = Get(self, id) 
            val = self.weights(char(id)); 
        end
        function kset = Keyset(self) 
            kset = keys(self.weights); 
        end
    end
end

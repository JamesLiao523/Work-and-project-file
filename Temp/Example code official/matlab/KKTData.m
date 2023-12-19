%% KKT Data Class
% container to hold KKT attributions for all the constaint
%

%%
classdef KKTData < handle
    properties (SetAccess='protected')
        kkt = KKTCons.empty;
    end
    
    methods
        %% APIs
        
        function AddConstraint(self, attr, cid, title)
            self.AddConstraintImpl(attr, cid, title, KKTCons.KKT_SIDE_DEFAULT, false);
        end
        
        function AddOnlyIfDifferent(self, attr, cid, title)
            self.AddOnlyIfDifferentImpl(attr, cid, title, KKTCons.KKT_DOWNSIDE, false);
        end
        
        function AddConstraintPenalty(self, attr, cid, title)
            self.AddConstraintImpl(attr, cid, title, KKTCons.KKT_SIDE_DEFAULT, true);
        end
        
        function AddOnlyIfDifferentPenalty(self, attr, cid, title)
            self.AddOnlyIfDifferentImpl(attr, cid, title, KKTCons.KKT_DOWNSIDE, true);
        end
        
        function print(self)
            if size(self.kkt, 2) == 0
                return;
            end
            
            fprintf('Constraint KKT attribution terms\n'); 
            % output header of KKT
            fprintf('Asset ID');
		
            for col = 1: size(self.kkt,2)
                cons = self.kkt(col);
                if cons.upOrDownside ~= KKTCons.KKT_DOWNSIDE
                    fprintf(', %s', char(cons.displayName));
                    if cons.upOrDownside == KKTCons.KKT_UPSIDE
                        fprintf('(up/down)');
                    end
                end
            end
		
            fprintf('\n');
        
            % output the weights
            keySet = self.kkt(1).Keyset();
            for i = 1: size(keySet, 2)
                id = keySet(i);
                fprintf('%s', char(id));
                for col = 1: size(self.kkt,2)
                    cons = self.kkt(col);
                    if cons.Contains(id) % there is a value
                        if cons.upOrDownside == KKTCons.KKT_DOWNSIDE % merged column
                            fprintf('/%.6f', cons.Get(id));
                        else
                            fprintf(', %.6f', cons.Get(id));
                        end
                    elseif cons.upOrDownside ~= KKTCons.KKT_DOWNSIDE % there is no value and not a merged column: empty column
                        fprintf(', ');
                    end
                end
                fprintf('\n');
            end
        end
    end
    
    methods (Access='protected')
        %% Actual function implementations
        function AddConstraintImpl(self, attr, cid, title, side, pen)
            idset = attr.GetKeySet();
            %check if it's an empty or all-zero column
            id = idset.GetFirst();
            i=0;
            while ~strcmp(id,'')
                %check if id is in the optimal portfolio
                if (size(self.kkt,2)==0) || self.kkt(1).Contains(id)
                    % larger than display threshold
                    val = attr.GetValue(id);
                    if val<0.0 
                        val = -val;
                    end
                    if val >=1.0e-6 
                        break;
                    end
                end
                id = idset.GetNext();
                i=i+1;
            end
            %not empty
            if i~=idset.GetCount()
                self.kkt = [self.kkt, KKTCons(attr, cid, title, side, pen)];
            end
        end

        function AddOnlyIfDifferentImpl(self, attr, cid, title, side, pen)
            idset = attr.GetKeySet();
            numCol = size(self.kkt, 2);
            % check if it's an empty or all-zero column
            id = idset.GetFirst();
            i=0;
            while ~strcmp(id,'')
                val = attr.GetValue(id);
                %excludes ids not in the optimal portfolio and same value as the column before
                if numCol==0 || (self.kkt(1).Contains(id) && val~=self.kkt(numCol).Get(id))
                    %larger than display threshold
                    if val<0.0 
                        val = -val;
                    end
                    if val >=1.0e-6 
                        break;
                    end
                end
                id = idset.GetNext();
                i=i+1;
            end
            
            % not empty
            if i~=idset.GetCount()
                self.kkt(numCol).upOrDownside = KKTCons.KKT_UPSIDE; % change previous column to upside
                self.kkt = [self.kkt, KKTCons(attr, cid, title, side, pen)];
            end
        end
    end
end
function status=explicit(jobname)
% -----------------------------------------------------------------------
%
%     Explicit finite element code
%
%
% -----------------------------------------------------------------------


% ---------------------  PREPROCESSOR  SECTION --------------------------
%clear
tic
status=1;

fprintf('\n----------------------------------------------------------------------------');
fprintf('\n|                                                                          |');
fprintf('\n|                                                                          |');
fprintf('\n|                                 FEMLAB CODE                              |');
fprintf('\n|                                                                          |');
fprintf('\n|      **************************************************************      |');
fprintf('\n|                                                                          |');
fprintf('\n|                               E X P L I C I T                            |');
fprintf('\n|                                                                          |');
fprintf('\n|                  S P E C T R A L    E L E M E N T    C O D E             |');
fprintf('\n|                                                                          |');
fprintf('\n|      **************************************************************      |');
fprintf('\n|                                                                          |');
fprintf('\n|       Written by Jack Chessa                                             |');
fprintf('\n|       jfchessa@utep.edu                                                  |');
fprintf('\n|       copyright 2010                                                     |');
fprintf('\n|                                                                          |');
fprintf('\n----------------------------------------------------------------------------');
fprintf('\n\n%8.2f: Reading input parameters\n',toc);


%--------------------
%
%  Flow over a cylinder
%
filename='block.msh';
domainPid=10;
ebcPid=12;
nbcPid=11;

% Read in mesh from the GMSH file
[nodeCoord,nids] = readnodes(filename);  % read in the node coordinate matrix
elementConn = readelements(filename,domainPid);  % the domain connectivity
loadElem = readelements(filename,nbcPid); % the ege connectivity for the NBC
fixedNodes = readnodeset(filename,ebcPid); % and the node ids on the EBC

% Sometimes gmsh does not number the nodes starting at one and
% consecutivley so the following functions renumber every thing 
[elementConn,nodeCoord,nodeMap]=renumber(elementConn,nids,nodeCoord); 
loadElem=renumber(loadElem,nodeMap);
fixedNodes=renumber(fixedNodes,nodeMap);


% % define the mesh
% nodeCoord=[0 0 0;
%     1 0 0;
%     2 0 0;
%     3 0 0;
%     4 0 0;
%     0 1 0;
%     1 1 0;
%     2 1 0;
%     3 1 0;
%     4 1 0 ];
% 
% % define the elements
% elementConn=[1 2 6;
%    	7 6 2;
%     2 3 7;
%     8 7 3;
%     3 4 8;
%     9 8 4;
%     4 5 9;
%     10 9 5 ];
%     
% loadElem=[1 6];
% fixedNodes=[5 10];

%--- now we can plot the mesh
clf
plot_mesh(nodeCoord,elementConn,'tria3')

% define the fixed global dofs
ifix = 2*fixedNodes-1;

% load parameters
pload = [2.0 0.0 0.0];
tload = [0 1;10 1];

% timeinfo
tfin=5e-5;
cfl=0.8;

% materl props
young = 10e6;
nu = 0.33333;
rho = 1.45e-4;

% ------------------------  SOLVER SECTION  -----------------------------
nn=size(nodeCoord,1);
ndof=2*nn;
ne=size(elementConn,1);

numHsv=1;
numQuadPts=1;

% compute steady state fext
fext=zeros(ndof,1);
for e=1:size(loadElem,1)
    n1=loadElem(e,1); n2=loadElem(e,2);
    sctr = [2*n1-1 2*n1 2*n2-1 2*n2];
    le = norm( nodeCoord(n1,:) - nodeCoord(n2,:) );
    fext(sctr) = fext(sctr) - 0.5*le*[pload(1);pload(2);pload(1);pload(2)];
end
    
% initialize system variables
mass=zeros(ndof,1);
fint=zeros(ndof,1);
avect=zeros(ndof,1);
dvect=zeros(ndof,1);
vvect=zeros(ndof,1);

sige=zeros(3,numQuadPts,ne); 
sigAvg=zeros(3,nn);     
sigCnt=zeros(nn,1);     

fprintf('\n\n%8.2f: Problem summary',toc);
fprintf('\n\t\tNumber of nodes:%-6i',nn);
fprintf('\n\t\tNumber of elements:%-6i',ne);
fprintf('\n\t\tNumber of dofs:%-6i',ndof);
fprintf('\n\t\tFinal time:%-7.4e\n',tfin);
fprintf('\n\n%8.2f: Starting time integration\n',toc);

% write the fe geometry
ensight_fegeometry('run.geom',nodeCoord,elementConn,'tria3');

tn=0.0;
tstep=0;
dt=.00001;
dtlast=0;
wtimes=[];
wi=0;

noutput=1;
nwrite=1;


% ******** CALCULATE MASS MATRIX HERE
massMat = sparse(ndof,ndof);

% CALCULATE THE STIFFNESS MATRIX HERE
stiffMat = sparse(ndof,ndof);
C=cmat_mat1(young,nu,'plane strain');
thk=1.0;
for e=1:ne
   
    conne = elementConn(e,:);
    coord = nodeCoord(conne,:);
    
    %[ke,A] = kmat_tria3(coord, young, nu, thk);
    [B,A]=bmat_tria3(coord);
ke=B'*C*B*A*thk;

    me = rho*thk*A/24*[2 0 1 0 1 0; 0 2 0 1 0 1;
        1 0 2 0 1 0; 0 1 0 2 0 1;
        1 0 1 0 2 0; 0 1 0 1 0 2];
        
    sctr(1:2:6)=2*conne-1;
    sctr(2:2:6)=2*conne;
    
    stiffMat(sctr,sctr) = stiffMat(sctr,sctr) + ke;
    massMat(sctr,sctr) = massMat(sctr,sctr) + me;
    
end


while ( tn<=tfin )
    
    fint=zeros(ndof,1);
    tscale=interp1(tload(:,1),tload(:,2),tn);
 
    fint = stiffMat*dvect;
   
    if ( mod(tstep,noutput)==0 && mod(tstep,nwrite)~=0 )
        fprintf('\n%8.2f: Time step=%6i, sim. time=%7.4e, time step=%7.4e\n',toc,tstep,tn,dt);
    end
    
    if ( mod(tstep,nwrite)==0 )
        fprintf('\n%8.2f: Time step=%6i, sim. time=%7.4e (writting data)\n',toc,tstep,tn);
        ensight_field(['run',num2str(wi,'%04d'),'.acc'],[avect(1:2:ndof) avect(2:2:ndof)]);
        ensight_field(['run',num2str(wi,'%04d'),'.vel'],[vvect(1:2:ndof) vvect(2:2:ndof)]);
        ensight_field(['run',num2str(wi,'%04d'),'.dsp'],[dvect(1:2:ndof) dvect(2:2:ndof)]);
        ensight_field(['run',num2str(wi,'%04d'),'.s11'],sigAvg(1,:));
        ensight_field(['run',num2str(wi,'%04d'),'.s22'],sigAvg(2,:));
        ensight_field(['run',num2str(wi,'%04d'),'.s12'],sigAvg(3,:));
        wi=wi+1;
        wtimes=[wtimes tn];
    end
    
%    avect = (fext*tscale-fint)./massMat;  %  **** IF THIS IS NOT DIAGONAL YOU WILL HAVE TO CHANGE THIS
    avect =  massMat\(fext*tscale-fint);
    avect(ifix)=0;
    vvect = vvect + dt*avect;
    %vvect(ifix)=0;
    dvect = dvect + dt*vvect;
    %dvect(ifix)=0;
    
    tn=tn+dt;
    dtlast=dt;
    tstep=tstep+1;
    
end % temporal loop


fprintf('\n\n%8.2f: End of time integration',toc);
ensight_case( 'run','run.geom',wtimes,...
    {'s11','s22','s12'},{'dsp','vel','acc'},{},...
    {},{},{} );

fprintf('\n----------------------------------------------------------------------------');
fprintf('\n|                                                                          |');
fprintf('\n|   ****************      E N D    O F    R U N     ****************       |');
fprintf('\n|                                                                          |');
fprintf('\n----------------------------------------------------------------------------\n\n');

status =0;

end
function  [fe, sige] = finternal( enode, de, young, nu )

    fe = zeros(6,1); 

    C = cmat_mat1( young, nu, 'pstrain' );

    x21=enode(2,1)-enode(1,1); x13=enode(1,1)-enode(3,1);  x32=enode(3,1)-enode(2,1);
    y12=enode(1,2)-enode(2,2); y31=enode(3,2)-enode(1,2);  y23=enode(2,2)-enode(3,2);

    A = 0.5*(x21*y31-x13*y12);
    B = 0.5/A*[	y23     0       y31     0       y12     0;
                0       x32     0       x13     0       x21;
                x32     y23     x13     y31     x21     y12 ];

    eps = B*de;
    sigma = C*eps;
    fe = fe + B'*sigma*A;

    sige=sigma;
    

end


% small def
function  [ dtstab, me ] = masscalc( enode, rho, young, nu )

    x21=enode(2,1)-enode(1,1); x13=enode(1,1)-enode(3,1);  x32=enode(3,1)-enode(2,1);
    y12=enode(1,2)-enode(2,2); y31=enode(3,2)-enode(1,2);  y23=enode(2,2)-enode(3,2);

    A = 0.5*(x21*y31-x13*y12);
    
    me = 0.25*A*rho*ones(6,1);
    
    he = sqrt(2*A);
	dtstab = he/sqrt(young/rho);
    me = sum(me)';
    
end



% % small def
% function  [fe, sige] = finternalQ4( Xe, de, young, nu )
% 
%     qpt=0.5773502691896257645091488*[ -1 -1;
%                                        1 -1;
%                                       -1  1;
%                                        1  1 ];
%     qwt=[1 1 1 1];
%     
%     fe = zeros(8,1);  me = fe;
%  
%     C = cmat_mat1( young, nu, 'pstrain' );
%     for q=1:length(qwt)
%         
%         s=qpt(q,1); t=qpt(q,2);
%         
%         N   = 0.25*[ (1-s)*(1-t); (1+s)*(1-t); (1+s)*(1+t); (1-s)*(1+t) ];
%         dNs = 0.25*[ t-1, 1-t,    1+t,  -1-t;  
% 		  			 s-1, -1-s,  1+s,   1-s ];
%   		
% 		JmatT = dNs*Xe(:,1:2);  % compute the Jacobian matrix at the quadrature point
% 		detj=det(JmatT);        % and the determinant.
%       
%         JinvT = inv(JmatT);
%         dNx = JinvT*dNs;
%         
% 		B = [ dNx(1,1)        0 dNx(1,2)        0 dNx(1,3)        0 dNx(1,4)        0; 
%                      0 dNx(2,1)        0 dNx(2,2)        0 dNx(2,3)        0 dNx(2,4); 
%               dNx(2,1) dNx(1,1) dNx(2,2) dNx(1,2) dNx(2,3) dNx(1,3) dNx(2,4) dNx(1,4) ]; 
%          
%         eps = B*de;
%         sigma = C*eps;    
%         fe = fe + B'*sigma*detj*qwt(q);
%         
%         sige(:,q)=sigma;   
%         
%     end
%     
%     sige = sige(:,[1 2 4 3]);
% 
% end
% 
% 
% % small def
% function  [ dtstab, me ] = masscalcQ4( Xe, rho, young, nu )
% 
%     qpt=0.5773502691896257645091488*[ -1 -1;
%                                        1 -1;
%                                       -1  1;
%                                        1  1 ];
%     qwt=[1 1 1 1];
%     
%     me = zeros(8,8);  
%     ke = zeros(8,8);  
%     
%     C = cmat_mat1( young, nu, 'pstrain' );
%     for q=1:length(qwt)
%         
%         s=qpt(q,1); t=qpt(q,2);
%         
%         N   = 0.25*[ (1-s)*(1-t); (1+s)*(1-t); (1+s)*(1+t); (1-s)*(1+t) ];
%         dNs = 0.25*[ t-1, 1-t,    1+t,  -1-t;  
% 		  			 s-1, -1-s,  1+s,   1-s ];
%   		
% 		JmatT = dNs*Xe(:,1:2);  % compute the Jacobian matrix at the quadrature point
% 		detj=det(JmatT);        % and the determinant.
%       
%         JinvT = inv(JmatT);
%         dNx = JinvT*dNs;
%         
% 		B = [ dNx(1,1)        0 dNx(1,2)        0 dNx(1,3)        0 dNx(1,4)        0; 
%                      0 dNx(2,1)        0 dNx(2,2)        0 dNx(2,3)        0 dNx(2,4); 
%               dNx(2,1) dNx(1,1) dNx(2,2) dNx(1,2) dNx(2,3) dNx(1,3) dNx(2,4) dNx(1,4) ]; 
%  
%         
%         ke = ke + B'*C*B*detj*qwt(q);
%         Nv(1:2:8) = N; Nv(2:2:8) = N;
%         me = me + Nv'*Nv*rho*detj*qwt(q);
%         
%     end
% 
% 	dtstab = 5/sqrt(young/rho);
%     me = sum(me)';
%     
% end
% 
% 

glmm_final_smooth<-function(y,X,Phi,W,k,penal.vec,q_start,Delta_start,s,steps=1000,
                     family,method,overdispersion,phi,nue=1,print.iter.final=FALSE,
                     eps.final=1e-5,Q.min=1e-13,Q.max=20,Q.fac=5)
{
dim.smooth<-dim(Phi)[2]  
N<-length(y)
lin<-ncol(as.matrix(X))
n<-length(k)
Eta<-cbind(X,Phi,W)%*%Delta_start
Mu<-as.vector(family$linkinv(Eta))
Sigma<-as.vector(family$variance(Mu))
if(overdispersion)
  Sigma<-Sigma*phi
D<-as.vector(family$mu.eta(Eta))
#W0_inv<-D*1/Sigma*D

if(print.iter.final)
  message("Final Re-estimation Iteration ", 1)
#print(paste("Final Re-estimation Iteration ", 1,sep=""))


Z_alles<-cbind(X,Phi,W)

if(s==1)
{
P1<-c(rep(0,lin),penal.vec,rep((q_start^(-1)),n*s))
P1<-diag(P1)
}else{
P1<-matrix(0,lin+dim.smooth+n*s,lin+dim.smooth+n*s)
diag(P1)[(lin+1):(lin+dim.smooth)]<-penal.vec
for(jf in 1:n)
P1[(lin+dim.smooth+(jf-1)*s+1):(lin+dim.smooth+jf*s),(lin+dim.smooth+(jf-1)*s+1):(lin+dim.smooth+jf*s)]<-chol2inv(chol(q_start))
}

#if(s==1)
#{
#  P.smooth<-c(rep(0,lin),penal.vec,rep(0,n*s))
#  P.smooth<-diag(P.smooth)
#}else{
#  P.smooth<-c(rep(0,lin),penal.vec,rep(0,n%*%s))
#  P.smooth<-diag(P.smooth)
#}


Delta<-matrix(0,steps,(lin+dim.smooth+s*n))
Eta.ma<-matrix(0,steps+1,N)
Eta.ma[1,]<-Eta

Q<-list()
Q[[1]]<-q_start


l=1
opt<-steps


score_vec<-t(Z_alles)%*%((y-Mu)*D*1/Sigma)-P1%*%Delta[1,]
F_gross<-t(Z_alles)%*%(Z_alles*D*1/Sigma*D)+P1



InvFisher<-try(chol2inv(chol(F_gross)),silent=TRUE)
if(class(InvFisher)=="try-error")
InvFisher<-try(solve(F_gross),silent=TRUE)  
if(class(InvFisher)=="try-error")
stop("Fisher matrix not invertible")



half.index<-0
solve.test<-FALSE
Delta_r<-InvFisher%*%score_vec

P1.old<-P1

######### big while loop for testing if the update leads to Fisher matrix which can be inverted
while(!solve.test)
{  
  
solve.test2<-FALSE  
while(!solve.test2)
{  
Delta[1,]<-Delta_start+nue*(0.5^half.index)*Delta_r

Eta<-Z_alles%*%Delta[1,]

Mu<-as.vector(family$linkinv(Eta))
Sigma<-as.vector(family$variance(Mu))
D<-as.vector(family$mu.eta(Eta))


if (method=="EM" || overdispersion)
{  
  F_gross<-t(Z_alles)%*%(Z_alles*D*1/Sigma*D)+P1.old
  InvFisher<-try(chol2inv(chol(F_gross)),silent=TRUE)
  if(class(InvFisher)=="try-error")
    InvFisher<-try(solve(F_gross),silent=TRUE)  
  if(class(InvFisher)=="try-error")
  {
    half.index<-half.index+1  
  }else{
    solve.test2<-TRUE 
}}else{
    solve.test2<-TRUE
}}

if (method=="EM")
{
############################# Q updaten ################
Q1<-InvFisher[(lin+dim.smooth+1):(lin+dim.smooth+s),(lin+dim.smooth+1):(lin+dim.smooth+s)]+Delta[1,(lin+dim.smooth+1):(lin+dim.smooth+s)]%*%t(Delta[1,(lin+dim.smooth+1):(lin+dim.smooth+s)])
for (i in 2:n)
Q1<-Q1+InvFisher[(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s),(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)]+Delta[1,(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)]%*%t(Delta[1,(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)])
Q1<-1/n*Q1
}else{
Eta_tilde<-Eta+(y-Mu)*1/D

Betadach<-Delta[1,1:(lin+dim.smooth)]

if(s==1)
{
low <- (1/Q.fac)*Q.min
upp <- Q.fac*Q.max
optim.obj<-nlminb(sqrt(q_start),likelihood_nlminb,D=D,Sigma=Sigma,X=cbind(X,Phi),X_aktuell=cbind(X,Phi),Eta_tilde=Eta_tilde,n=n,Betadach=Betadach,W=W,lower = low, upper= upp)
Q1<-as.matrix(optim.obj$par)^2
}else{
q_start_vec<-c(diag(q_start),q_start[lower.tri(q_start)])
up1<-Q.fac*Q.max
upp<-rep(up1,length(q_start_vec))
low<-c(rep(0,s),rep(-up1,0.5*(s^2-s)))
kkk_vec<-c(rep(-1,s),rep(0.5,0.5*(s^2-s)))
optim.obj<-bobyqa(q_start_vec,likelihood,D=D,Sigma=Sigma,X=cbind(X,Phi),X_aktuell=cbind(X,Phi),Eta_tilde=Eta_tilde,Betadach=Betadach,W=W,n=n,s=s,k=k,lower=low,upper=upp)
Q1<-matrix(0,s,s)
Q1[lower.tri(Q1)]<-optim.obj$par[(s+1):(s*(s+1)*0.5)]
Q1<-Q1+t(Q1)
diag(Q1)<-(optim.obj$par[1:s])

#### Check for positive definitness ########
      for (ttt in 0:100)
      {
      Q1[lower.tri(Q1)]<-((0.5)^ttt)*Q1[lower.tri(Q1)]
      Q1[upper.tri(Q1)]<-((0.5)^ttt)*Q1[upper.tri(Q1)]
      Q_solvetest<-try(solve(Q1))
         if(all (eigen(Q1)$values>0) & class(Q_solvetest)!="try-error")
         break
      }
}}

Q[[2]]<-Q1


if(overdispersion)
{
FinalHat<-(Z_alles*sqrt(Sigma*D*1/Sigma*D))%*%InvFisher%*%t(Z_alles*sqrt(D*1/Sigma*D*1/Sigma))#E-Uu
phi<-(sum((y-Mu)^2/Mu))/(N-sum(diag(FinalHat)))
Sigma<-Sigma*phi
}


if(s==1)
{
  P1<-c(rep(0,lin),penal.vec,rep((Q1^(-1)),n*s))
  P1<-diag(P1)
}else{
  P1<-matrix(0,lin+dim.smooth+n*s,lin+dim.smooth+n*s)
  diag(P1)[(lin+1):(lin+dim.smooth)]<-penal.vec
  for(jf in 1:n)
    P1[(lin+dim.smooth+(jf-1)*s+1):(lin+dim.smooth+jf*s),
       (lin+dim.smooth+(jf-1)*s+1):(lin+dim.smooth+jf*s)]<-chol2inv(chol(Q1))
}

score_vec<-t(Z_alles)%*%((y-Mu)*D*1/Sigma)-P1%*%Delta[1,]
F_gross<-t(Z_alles)%*%(Z_alles*D*1/Sigma*D)+P1

InvFisher<-try(chol2inv(chol(F_gross)),silent=TRUE)
if(class(InvFisher)=="try-error")
  InvFisher<-try(solve(F_gross),silent=TRUE)  
if(class(InvFisher)=="try-error")
{
  half.index<-half.index+1  
}else{
  solve.test<-TRUE 
}
}

Eta.ma[2,]<-Eta

P1.old.temp<-P1.old
###############################################################################################################################################
################################################################### Main Iteration ###################################################################
eps<-eps.final*sqrt(length(Delta_r))


for (l in 2:steps)
{
if(print.iter.final)
  message("Final Re-estimation Iteration ", l)
#print(paste("Final Re-estimation Iteration ", l,sep=""))

half.index<-0
solve.test<-FALSE

P1.old<-P1

Delta_r<-InvFisher%*%score_vec
######### big while loop for testing if the update leads to Fisher matrix which can be inverted
first.time<-FALSE
while(!solve.test)
{  
  
solve.test2<-FALSE  
while(!solve.test2)
{  
if(half.index>100)
{
half.index<-Inf;P1.old<-P1.old.temp
}
Delta[l,]<-Delta[l-1,]+nue*(0.5^half.index)*Delta_r

Eta<-Z_alles%*%Delta[l,]
Mu<-as.vector(family$linkinv(Eta))
Sigma<-as.vector(family$variance(Mu))
D<-as.vector(family$mu.eta(Eta))

if (method=="EM" || overdispersion)
{  
  F_gross<-t(Z_alles)%*%(Z_alles*D*1/Sigma*D)+P1.old
  InvFisher2<-try(chol2inv(chol(F_gross)),silent=TRUE)
  if(class(InvFisher2)=="try-error")
    InvFisher2<-try(solve(F_gross),silent=TRUE)  
  if(class(InvFisher2)=="try-error")
  {
    half.index<-half.index+1  
  }else{
    if(!first.time)
    half.index.final<-half.index
    solve.test2<-TRUE 
    first.time<-TRUE
  }}else{
    if(!first.time)
    half.index.final<-half.index
    solve.test2<-TRUE 
    first.time<-TRUE
  }}

if (method=="EM")
{
############################# Q update ################
Q1<-InvFisher2[(lin+dim.smooth+1):(lin+dim.smooth+s),(lin+dim.smooth+1):(lin+dim.smooth+s)]+Delta[l,(lin+dim.smooth+1):(lin+dim.smooth+s)]%*%t(Delta[l,(lin+dim.smooth+1):(lin+dim.smooth+s)])

for (i in 2:n)
Q1<-Q1+InvFisher2[(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s),(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)]+Delta[l,(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)]%*%t(Delta[l,(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)])

Q1<-1/n*Q1
}else{
Eta_tilde<-Eta+(y-Mu)*1/D

Betadach<-Delta[l,1:(lin+dim.smooth)]

if(s==1)
{
upp<-max(upp,Q.fac*Q1)
low<-min(low,(1/Q.fac)*Q1)
optim.obj<-nlminb(sqrt(Q1),likelihood_nlminb,D=D,Sigma=Sigma,X=cbind(X,Phi),X_aktuell=cbind(X,Phi),Eta_tilde=Eta_tilde,n=n,Betadach=Betadach,W=W, lower = low, upper = upp)
Q1<-as.matrix(optim.obj$par)^2
}else{
up1<-max(up1,Q.fac*max(Q1))  
upp<-rep(up1,length(q_start_vec))
low<-c(rep(0,s),rep(-up1,0.5*(s^2-s)))
Q1_vec<-c(diag(Q1),Q1[lower.tri(Q1)])
optim.obj<-bobyqa(Q1_vec,likelihood,D=D,Sigma=Sigma,X=cbind(X,Phi),X_aktuell=cbind(X,Phi),Eta_tilde=Eta_tilde,n=n,s=s,k=k,Betadach=Betadach,W=W,lower=low,upper=upp)

Q1<-matrix(0,s,s)
Q1[lower.tri(Q1)]<-optim.obj$par[(s+1):(s*(s+1)*0.5)]
Q1<-Q1+t(Q1)
diag(Q1)<-(optim.obj$par[1:s])

#### Check for positiv definitness ########
for (ttt in 0:100)
      {
      Q1[lower.tri(Q1)]<-((0.5)^ttt)*Q1[lower.tri(Q1)]
      Q1[upper.tri(Q1)]<-((0.5)^ttt)*Q1[upper.tri(Q1)]
       Q_solvetest<-try(solve(Q1))
         if(all (eigen(Q1)$values>0) & class(Q_solvetest)!="try-error")
         break
      }
}}

Q[[l+1]]<-Q1
#print(Q1)

if(overdispersion)
{
FinalHat<-(Z_alles*sqrt(Sigma*D*1/Sigma*D))%*%InvFisher%*%t(Z_alles*sqrt(D*1/Sigma*D*1/Sigma))#E-Uu
phi<-(sum((y-Mu)^2/Mu))/(N-sum(diag(FinalHat)))
Sigma<-Sigma*phi
}


if(s==1)
{
  P1<-c(rep(0,lin),penal.vec,rep((Q1^(-1)),n*s))
  P1<-diag(P1)
}else{
  P1<-matrix(0,lin+dim.smooth+n*s,lin+dim.smooth+n*s)
  diag(P1)[(lin+1):(lin+dim.smooth)]<-penal.vec
  for(jf in 1:n)
    P1[(lin+dim.smooth+(jf-1)*s+1):(lin+dim.smooth+jf*s),
       (lin+dim.smooth+(jf-1)*s+1):(lin+dim.smooth+jf*s)]<-chol2inv(chol(Q1))
}

score_vec<-t(Z_alles)%*%((y-Mu)*D*1/Sigma)-P1%*%Delta[l,]
F_gross<-t(Z_alles)%*%(Z_alles*D*1/Sigma*D)+P1

InvFisher<-try(chol2inv(chol(F_gross)),silent=TRUE)
if(class(InvFisher)=="try-error")
  InvFisher<-try(solve(F_gross),silent=TRUE)  
if(class(InvFisher)=="try-error")
{
  half.index<-half.index+1  
}else{
  solve.test<-TRUE 
}
}

Eta.ma[l+1,]<-Eta


P1.old.temp<-P1.old

finish<-(sqrt(sum((Eta.ma[l,]-Eta.ma[l+1,])^2))/sqrt(sum((Eta.ma[l,])^2))<eps)
finish2<-(sqrt(sum((Eta.ma[l-1,]-Eta.ma[l+1,])^2))/sqrt(sum((Eta.ma[l-1,])^2))<eps)

if(finish ||  finish2) 
  break
}

######## Final calculation

opt<-l


if(!solve.test)
{
  Delta[l,]<-Delta[l-1,]+nue*(0.5^half.index.final)*Delta_r
  Eta<-Z_alles%*%Delta[l,]
  Mu<-as.vector(family$linkinv(Eta))
  Sigma<-as.vector(family$variance(Mu))
  D<-as.vector(family$mu.eta(Eta))
  
  if (method=="EM" || overdispersion)
  {  
    F_gross<-t(Z_alles)%*%(Z_alles*D*1/Sigma*D)+P1.old
    InvFisher2<-try(chol2inv(chol(F_gross)),silent=TRUE)
    if(class(InvFisher2)=="try-error")
      InvFisher2<-try(solve(F_gross),silent=TRUE)  
  }

if (method=="EM")
{
  ############################# Q update ################
  Q1<-InvFisher2[(lin+dim.smooth+1):(lin+dim.smooth+s),(lin+dim.smooth+1):(lin+dim.smooth+s)]+Delta[l,(lin+dim.smooth+1):(lin+dim.smooth+s)]%*%t(Delta[l,(lin+dim.smooth+1):(lin+dim.smooth+s)])
  
  for (i in 2:n)
    Q1<-Q1+InvFisher2[(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s),(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)]+Delta[l,(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)]%*%t(Delta[l,(lin+dim.smooth+(i-1)*s+1):(lin+dim.smooth+i*s)])
  
  Q1<-1/n*Q1
}else{
  Eta_tilde<-Eta+(y-Mu)*1/D
  
  Betadach<-Delta[l,1:(lin+dim.smooth)]
  
  if(s==1)
  {
    upp<-max(upp,Q.fac*Q1)
    low<-min(low,(1/Q.fac)*Q1)
    optim.obj<-nlminb(sqrt(Q1),likelihood_nlminb,D=D,Sigma=Sigma,X=cbind(X,Phi),X_aktuell=cbind(X,Phi),Eta_tilde=Eta_tilde,n=n,Betadach=Betadach,W=W, lower = low, upper = upp)
    Q1<-as.matrix(optim.obj$par)^2
  }else{
    up1<-max(up1,Q.fac*max(Q1))  
    upp<-rep(up1,length(q_start_vec))
    low<-c(rep(0,s),rep(-up1,0.5*(s^2-s)))
    Q1_vec<-c(diag(Q1),Q1[lower.tri(Q1)])
    optim.obj<-bobyqa(Q1_vec,likelihood,D=D,Sigma=Sigma,X=cbind(X,Phi),X_aktuell=cbind(X,Phi),Eta_tilde=Eta_tilde,n=n,s=s,k=k,Betadach=Betadach,W=W,lower=low,upper=upp)
    
    Q1<-matrix(0,s,s)
    Q1[lower.tri(Q1)]<-optim.obj$par[(s+1):(s*(s+1)*0.5)]
    Q1<-Q1+t(Q1)
    diag(Q1)<-(optim.obj$par[1:s])
    
    #### Check for positiv definitness ########
    for (ttt in 0:100)
    {
      Q1[lower.tri(Q1)]<-((0.5)^ttt)*Q1[lower.tri(Q1)]
      Q1[upper.tri(Q1)]<-((0.5)^ttt)*Q1[upper.tri(Q1)]
      Q_solvetest<-try(solve(Q1))
      if(all (eigen(Q1)$values>0) & class(Q_solvetest)!="try-error")
        break
    }
  }}

Q[[l+1]]<-Q1


  FinalHat<-(Z_alles*sqrt(Sigma*D*1/Sigma*D))%*%InvFisher%*%t(Z_alles*sqrt(D*1/Sigma*D*1/Sigma))
  complexity<-sum(diag(FinalHat))

if(overdispersion)
{
  phi<-(sum((y-Mu)^2/Mu))/(N-complexity)
  Sigma<-Sigma*phi
}
}

FinalHat<-(Z_alles*sqrt(Sigma*D*1/Sigma*D))%*%InvFisher%*%t(Z_alles*sqrt(D*1/Sigma*D*1/Sigma))
complexity<-sum(diag(FinalHat))

Deltafinal<-Delta[l,]
Q_final<-Q[[l+1]]

Standard_errors<-sqrt(diag(InvFisher))


#FinalHat<-(Z_alles*sqrt(D*1/Sigma*D))%*%InvFisher%*%t(Z_alles*sqrt(D*1/Sigma*D))

#### compare Wood's Book on page 167
if(s==1)
{
  P1a<-c(rep(0,lin+dim.smooth),rep((Q1^(-1)),n*s))
  P1a<-diag(P1a)
}else{
  P1a<-matrix(0,lin+dim.smooth+n*s,lin+dim.smooth+n*s)
  for(jf in 1:n)
    P1a[(lin+dim.smooth+(jf-1)*s+1):(lin+dim.smooth+jf*s),
        (lin+dim.smooth+(jf-1)*s+1):(lin+dim.smooth+jf*s)]<-chol2inv(chol(Q1))
}
#### compare Wood's Book on page 167
EDF.matrix<-InvFisher%*%(t(Z_alles)%*%(Z_alles*D*1/Sigma*D)+P1a)


## compute ranef part of loglik
if(s==1)
{
  P1.ran<-rep((Q_final^(-1)),n*s)
  P1.ran<-diag(P1.ran)
}else{
  P1.ran<-matrix(0,n*s,n*s)
  for(jf in 1:n)
    P1.ran[((jf-1)*s+1):(jf*s),((jf-1)*s+1):(jf*s)]<-chol2inv(chol(Q_final))
}

ranef.logLik<--0.5*t(Deltafinal[(lin+dim.smooth+1):(lin+dim.smooth+n*s)])%*%P1.ran%*%Deltafinal[(lin+dim.smooth+1):(lin+dim.smooth+n*s)]

ret.obj=list()
ret.obj$ranef.logLik<-ranef.logLik
ret.obj$opt<-opt
ret.obj$Delta<-Deltafinal
ret.obj$Q<-Q_final
ret.obj$Standard_errors<-Standard_errors
ret.obj$phi<-phi
ret.obj$EDF.matrix<-EDF.matrix
ret.obj$complexity<-complexity
return(ret.obj)
}



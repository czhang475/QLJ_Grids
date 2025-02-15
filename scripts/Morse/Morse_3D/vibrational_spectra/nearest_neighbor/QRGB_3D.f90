!=============================================================================80
!                      3D Morse Code with QRG and GHQ
!==============================================================================!
!Quasi-Regular Grid for computing vibrational spectra
!generate alpha based on nearest neghbor
!see distribtuion code for alpha as a funciton of the target distribution
!This code needs the gen_hermite_rule.f90 code (Gauss-Hermite-Quadriture)
!==============================================================================!
!       Modified:
!   15 May 2019
!       Author:
!   Shane Flynn 
!==============================================================================!
module QRGB_mod
implicit none
!==============================================================================!
!                            Global Variables 
!==============================================================================!
!d              ==>i-th gaussian dsionality (x^i=x^i_1,x^i_2,..,x^i_d)
!==============================================================================!
integer::d
!==============================================================================!
contains
!==============================================================================!
function V(x)
!==============================================================================!
!Hard-coded Morse Potential Energy 
!==============================================================================!
!x              ==>(d) ith particles coordinate x^i_1,..,x^i_d
!V              ==>evaluate V(x)
!D_morse        ==>Parameter for Morse Potential
!omega          ==>(d) Parameter for Morse Potential
!==============================================================================!
implicit none
double precision::x(d),V
double precision,parameter::omega(3)=(/0.2041241,0.18371169,0.16329928/)
double precision,parameter::D_morse=12.
V=D_morse*sum((exp(-omega(:)*x(:))-1.)**2 )
end function V
!==============================================================================!
!==============================================================================!
end module QRGB_mod
!==============================================================================!
!==============================================================================!
program main
use QRGB_mod
!==============================================================================!
!unif_grid      ==>If true alpha=constant, else alpha=alpha(distribution)
!grid_in        ==>Filename Containing Gridpoints, see qlj_morse2d_grid.f90
!theory_in      ==>Filename Containing Analytic Eigenvalues, see theory.f90
!theory         ==>(NG) Analytic Eigenvalues
!NG             ==>Number of Gaussian Basis Functions (gridpoints)
!GH_order       ==>Number of Points for evaluating the potential (Gauss-Hermite)
!alpha0         ==>Flat Scaling Parameter for Gaussian Widths
!alpha          ==>(d) Gaussian Widths
!RCN            ==>Recriprical Convergence Number, stability of Overlap Matrix
!x              ==>(d) ith atoms coordinates
!x_ij           ==>i-jth gaussian center (product of Gaussians is a Gaussian)
!Smat           ==>(NG,NG) Overlap Matrix
!Hmat           ==>(NG,NG) Hamiltonian Matrix
!==============================================================================!
implicit none
logical::unif_grid
character(len=50)::grid_in,theory_in
integer::NG,GH_order,i,j,l1,l2,l3
double precision,parameter::pi=4.*atan(1d0)
double precision::aij,r2,alpha0,Vij,RCN
double precision,allocatable,dimension(:)::alpha,eigenvalues,x_ij,z,w,rr,theory
double precision,allocatable,dimension(:,:)::x,Smat,Hmat
!==============================================================================!
!                       LLAPACK dsygv variables                                !
!==============================================================================!
integer::itype,info,lwork
double precision,allocatable,dimension(:)::work
!==============================================================================!
!                           Read Input Data File                               !
!==============================================================================!
read(*,*) d
read(*,*) NG
read(*,*) GH_order
read(*,*) grid_in
read(*,*) theory_in
read(*,*) alpha0
!==============================================================================!
!                               Allocations
!==============================================================================!
allocate(x(d,NG),x_ij(d),rr(d),alpha(NG),eigenvalues(NG),Smat(NG,NG))
allocate(Hmat(NG,NG),theory(NG),z(GH_order),w(GH_order))
write(*,*) 'Test 0; Successfully Read Input File'
!==============================================================================!
!                           Read GridPoints x(d,NG)
!==============================================================================!
open(17,File=grid_in)
do i=1,NG
    read(17,*) x(:,i)
enddo 
close(17)
!==============================================================================!
!                       Generate Alphas alpha(NG)
!           Use nearest neighbor to define width alpha(NG)
!==============================================================================!
do i=1,NG
    alpha(i)=1d20                            !large distance for placeholder
    do j=1,NG
        if(j.ne.i) then
            r2=sum((x(:,i)-x(:,j))**2)          !distance between gridpoints
            if(r2<alpha(i)) alpha(i)=r2
        endif
    enddo
    alpha(i)=alpha0/alpha(i)
enddo
write(*,*) 'Test 1; Successfully Generated Alphas from nearest neighbor'
!==============================================================================!
!                          Write Alphas to File 
!==============================================================================!
open(unit=18,file='alphas.dat')
do i=1,NG
    write(18,*) alpha(i)
enddo
close(18)
!==============================================================================!
!                           Overlap Matrix (S)
!==============================================================================!
do i=1,NG
    do j=i,NG
         aij=alpha(i)*alpha(j)/(alpha(i)+alpha(j))
         r2=sum((x(:,i)-x(:,j))**2)
!different from 2D
         Smat(i,j)=(2*sqrt(alpha(i)*alpha(j))/(alpha(i)+alpha(j)))**(0.5*d)&
             *exp(-aij*r2)
       Smat(j,i)=Smat(i,j)
    enddo
enddo
!==============================================================================!
!                   Check to see if S is positive definite
!If this is removed, you need to allocate llapack arrays before Hamiltonian 
!==============================================================================!
lwork=max(1,3*NG-1)
allocate(work(max(1,lwork)))
call dsyev('v','u',NG,Smat,NG,eigenvalues,work,Lwork,info)
write(*,*) 'Info (Initial Overlap Matrix) ==> ', info
RCN=eigenvalues(1)/eigenvalues(NG)
write(*,*) 'RCN =', RCN
open(unit=19,file='overlap_eigenvalues.dat')
do i=1,NG
    write(19,*) eigenvalues(i)
enddo
close(19)
write(*,*) 'Test 2; Overlap Matrix is Positive Definite'
!==============================================================================!
!             Use Gauss Hermit quadrature to evaluate the potential matrix
! z(GH-order) w(GH-order) --- quadrature points and weights
!==============================================================================!
call cgqf(GH_order,6,0d0,0d0,0d0,1d0,z,w)
!different from 2D
w=w/sqrt(pi)  
!==============================================================================!
!                   Solve Generalized Eigenvalue Problem
!==============================================================================!
do i=1,NG
  do j=i,NG
     aij=alpha(i)*alpha(j)/(alpha(i)+alpha(j))
     r2=sum((x(:,i)-x(:,j))**2)
     Smat(i,j)=(2*sqrt(alpha(i)*alpha(j))/(alpha(i)+alpha(j)))**(0.5*d)&
         *exp(-aij*r2)   
     Smat(j,i)=Smat(i,j)
!==============================================================================!
!                          Kinetic Energy Matrix
!==============================================================================!
     Hmat(i,j)=aij*(d-2*aij*r2)
!==============================================================================!
!                         Potential Energy Matrix
!==============================================================================!
     x_ij(:)=(alpha(i)*x(:,i)+alpha(j)*x(:,j))/(alpha(i)+alpha(j))
     Vij=0d0
     do l1=1,GH_order
        do l2=1,GH_order
           do l3=1,GH_order
              rr(1)=z(l1)
              rr(2)=z(l2)
              rr(3)=z(l3)
              rr=x_ij+rr/sqrt(alpha(i)+alpha(j))           
              Vij=Vij+w(l1)*w(l2)*w(l3)*V(rr)
           enddo
        enddo
     enddo
!==============================================================================!
!                      Hamiltonian = Kinetic + Potential
!==============================================================================!
     Hmat(i,j)=(Hmat(i,j)+Vij)*Smat(i,j)
     Hmat(j,i)=Hmat(i,j)
  enddo
enddo
itype=1
call dsygv(itype,'n','u',NG,Hmat,NG,Smat,NG,eigenvalues,work,Lwork,info)
write(*,*) 'info ==> ', info
open(unit=20,file='eigenvalues.dat')
write(20,*) alpha0, eigenvalues(:)
close(20)
!==============================================================================!
!                              Exact Eigenvalues
!==============================================================================!
open(21,File=theory_in)
do i=1,NG
    read(21,*) theory(i)
enddo 
close(21)
open(unit=22,file='abs_error.dat')
open(unit=23,file='rel_error.dat')
open(unit=24,file='alpha_abs_error.dat')
open(unit=25,file='alpha_rel_error.dat')
do i=1,NG
        write(22,*) i, abs(theory(i)-eigenvalues(i))
        write(23,*) i, (eigenvalues(i)-theory(i))/theory(i)
        write(24,*) alpha0, abs(theory(i)-eigenvalues(i))
        write(25,*) alpha0, (eigenvalues(i)-theory(i))/theory(i)
enddo
close(22)
close(23)
close(24)
close(25)
open(unit=26,file='alpha_rel_150.dat')
do i=1,150
        write(26,*) alpha0, (eigenvalues(i)-theory(i))/theory(i)
enddo
close(26)
!==============================================================================!
!                               output file                                    !
!==============================================================================!
open(99,file='simulation.dat')
write(99,*) 'dimensionality ==> ', d
write(99,*) 'NG ==> ', NG
write(99,*) 'alpha0==>', alpha0
write(99,*) 'RCN Overlap Matrix==>', RCN
write(99,*) 'GH Order==>', GH_order
write(99,*) 'RCN==>', RCN
close(99)
write(*,*) 'Hello Universe!'
end program main

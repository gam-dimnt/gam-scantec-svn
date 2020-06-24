!-----------------------------------------------------------------------------!
!           Group on Data Assimilation Development - GDAD/CPTEC/INPE          !
!-----------------------------------------------------------------------------!
!BOP
!
! !MODULE: m_brams.f90
!
! !DESCRIPTON: This module contains routines and functions to configure,
!              read and interpolate fields of the model to use in scantec.
!                 
!\\
!\\
! !INTERFACE:
!

MODULE m_brams

!
! !USES:
!
  USE scantec_module                ! scantec types
  USE scan_dataMOD, only : scandata ! scantec data matrix
  USE interp_mod                    ! Interpolation module
  USE m_die                         ! Error Messages
  USE m_stdio                       ! Module to defines std. I/O parameters
  USE scan_MetForm                  ! Module to conversion of meteorological variables
  USE bramsIO


  IMPLICIT NONE
  PRIVATE
!
! !PUBLIC TYPES:  
!
  type brams_type_dec 

     integer                :: npts
     real, allocatable      :: gridDesc(:)
     real, allocatable      :: rlat1(:)
     real, allocatable      :: rlon1(:)
     integer, allocatable   :: n111(:)
     integer, allocatable   :: n121(:)
     integer, allocatable   :: n211(:)
     integer, allocatable   :: n221(:)
     real, allocatable      :: w111(:),w121(:)
     real, allocatable      :: w211(:),w221(:)

  end type brams_type_dec

  type(brams_type_dec) :: brams_struc
!
! !PUBLIC MEMBER FUNCTIONS:
!
  public :: brams_read ! Function to read files from brams model
  public :: brams_init ! Function to initilize weights to interpolate fields
!
!
! !REVISION HISTORY:
!  03 May 2012 - J. G. de Mattos - Initial Version
!  06 May 2012 - J. G. de Mattos - Include new fields read
!  17 Oct 2012 - J. G. de Mattos - change UMES to g/kg
!  20 Feb 2013 - J. G. de Mattos - include scan_MetForm.f90 
!                                - and use it to make conversions
!
!
!
! !SEE ALSO:
!   
!
!EOP
!-----------------------------------------------------------------------------!
!
  character(len=*),parameter :: myname='m_brams' 

CONTAINS
!
!-----------------------------------------------------------------------------!
!BOP
!
! !IROUTINE:  brams_init
!
! !DESCRIPTION: This function initialize the matrices used to read 
!               and export fields to scantec
!\\
!\\
! !INTERFACE:
!

  SUBROUTINE brams_init()

!
!
! !REVISION HISTORY: 
!  03 May 2012 - J. G. de Mattos - Initial Version
!
!
!EOP
!-----------------------------------------------------------------------------!
!BOC
!
  
    IMPLICIT NONE
    integer :: nx, ny
    character(len=*),parameter :: myname_=myname//'::brams_init'

    !
    ! DEBUG print
    !

#ifdef DEBUG
    WRITE(stdout,'(     2A)')'Hello from ', myname_
#endif

    Allocate(brams_struc%gridDesc(50))

    call brams_domain()

    nx = int(scantec%gridDesc(2))
    ny = int(scantec%gridDesc(3))

    Allocate(brams_struc%rlat1(nx*ny))
    Allocate(brams_struc%rlon1(nx*ny))              
    Allocate(brams_struc%n111(nx*ny))
    Allocate(brams_struc%n121(nx*ny))
    Allocate(brams_struc%n211(nx*ny))
    Allocate(brams_struc%n221(nx*ny))
    Allocate(brams_struc%w111(nx*ny))
    Allocate(brams_struc%w121(nx*ny))
    Allocate(brams_struc%w211(nx*ny))
    Allocate(brams_struc%w221(nx*ny))

   !
   ! Initializing arrays of weights for interpolation in the field of scantec
   !

    call bilinear_interp_input(brams_struc%gridDesc, scantec%gridDesc,        &
                               int(scantec%gridDesc(2)*scantec%gridDesc(3)), &
                                     brams_struc%rlat1,brams_struc%rlon1,      &
                                     brams_struc%n111,brams_struc%n121,        &
                                     brams_struc%n211,brams_struc%n221,        &
                                     brams_struc%w111,brams_struc%w121,        &
                                     brams_struc%w211,brams_struc%w221)


  END SUBROUTINE brams_init
!
!EOC
!
!-----------------------------------------------------------------------------!
!BOP
!
! !IROUTINE:  brams_domain
!
! !DESCRIPTION: This routine initilize domain parameters of brams model
!               
!\\
!\\
! !INTERFACE:
!

  SUBROUTINE brams_domain()

!
!
! !REVISION HISTORY: 
!  03 May 2012 - J. G. de Mattos - Initial Version
!
!
!EOP
!-----------------------------------------------------------------------------!
!BOC
!
  
    IMPLICIT NONE
    character(len=*),parameter :: myname_=myname//'::brams_domain'

    !
    ! DEBUG print
    !

#ifdef DEBUG
    WRITE(stdout,'(     2A)')'Hello from ', myname_
#endif

    brams_struc%gridDesc     = 0 

    brams_struc%gridDesc( 1) = 0         !Input grid type (4=Gaussian)
    brams_struc%gridDesc( 2) = 1159      !Number of points on a lat circle
    brams_struc%gridDesc( 3) = 1367      !Number of points on a meridian
    brams_struc%gridDesc( 4) = -47.      !Latitude of origin
    brams_struc%gridDesc( 5) = -82.133   !Longitude of origin
    brams_struc%gridDesc( 6) = 128       !8 bits (1 byte) related to resolution
                                            !(recall that 10000000 = 128), Table 7
    brams_struc%gridDesc( 7) = 11.0196   !Latitude of extreme point
    brams_struc%gridDesc( 8) = -26.9032  !Longitude of extreme point
    brams_struc%gridDesc( 9) = 0.0424741 !N/S direction increment
    brams_struc%gridDesc(10) = 0.0476941 !(Gaussian) # lat circles pole-equator
    brams_struc%gridDesc(20) = 0.0  

    brams_struc%npts = brams_struc%gridDesc(2)*brams_struc%gridDesc(3)

  END SUBROUTINE brams_domain
!
!EOC
!
!-----------------------------------------------------------------------------!
!BOP
!
! !IROUTINE:  brams_read
!
! !DESCRIPTION: For a given file name, read fields from a brams model,
!               interpolates to the scantec domain and export to scantec
!               matrices.                
!               
!\\
!\\
! !INTERFACE:
!

  SUBROUTINE brams_read(fname)
    IMPLICIT NONE
!
! !INPUT PARAMETERS:
!
  
    character(len=*), intent(IN) :: fname ! File name of the brams model

!
!
! !REVISION HISTORY: 
!  03 May 2012 - J. G. de Mattos - Initial Version
!
!
!EOP
!-----------------------------------------------------------------------------!
!BOC
!
    character(len=*),parameter :: myname_=myname//'::brams_read'

    integer :: iret, jret, gbret, stat
    logical :: file_exists
    integer :: jpds(200),jgds(200),gridDesc(200),kpds(200)
    integer :: lugb
    real    :: lubi
    real    :: kf,k
    integer :: i,j,iv,y
    integer :: npts
    integer :: nx
    integer :: ny
    integer, dimension(20) :: pds5, pds7
    logical*1, dimension(:,:), allocatable :: lb, lb2
    real, dimension(:,:), allocatable :: f
    real, dimension(:,:), allocatable :: f2
    real, dimension(:),   allocatable :: varfield
    character(10) :: dataini, datafinal
    real :: undef =  -9.99e+33
    real, dimension(:,:), allocatable :: tempc, rh
    real, dimension(3):: lev
    real, allocatable, dimension(:) :: ee, es, rv, qq
    integer :: unidade

    !
    !  0. Hello
    !

#ifdef DEBUG
    WRITE(stdout,'(     2A)')'Hello from ', myname_
    WRITE(stdout,'( A,1X,A)')'Open File ::', trim(fname)
#endif

    !
    !
    !

    lugb = 1
    lubi = 0
    j    = 0
    jpds = -1 
    !        TV   TV  TV  T   T   T   P   Q   Q   Q   A   Z   Z   Z   U   U   U   V   V   V 
    pds5 = (/055,057,064,057,064,069,003,112,114,121,021,133,140,145,076,083,088,095,102,107/) !parameter
    pds7 = (/925,850,500,850,500,250,000,925,850,500,925,850,500,250,850,500,250,850,500,250/) !htlev2

    allocate(lb2(brams_struc%npts,scantec%nvar))
    allocate(lb(brams_struc%npts,size(pds5)))
    lb  = .true.
    lb2 = .true.


    allocate(f(brams_struc%npts,size(pds5)))
    
    allocate(es(brams_struc%npts))
    allocate(ee(brams_struc%npts))
    allocate(rv(brams_struc%npts))



    inquire (file=trim(fname), exist=file_exists)

    if(file_exists) then
       call abrir_arq(fname, unidade,brams_struc%npts, iret)
       if(iret .eq. 0) then

          !Temperatura p/ temperatura virtual
          call ler_arq2(unidade,pds5(1:3),f(:,1:3))
          where(f(:,1:3).eq.undef)lb(:,1:3) = .false.

          !Temperatuar Absoluta
          call ler_arq2(unidade,pds5(4:6),f(:,4:6))
          where(f(:,4:6).eq.undef)lb(:,4:6) = .false.
				  
          !Pressão redusida
          call ler_arq2(unidade,pds5(7:7),f(:,7:7))
          where(f(:,7:7).eq.undef)lb(:,7:7) = .false.
				
          !Umidade relativa p/ umidade especifica
          call ler_arq2(unidade,pds5(8:10),f(:,8:10))
          where(f(:,8:10).eq.undef)lb(:,8:10) = .false.
				
          !AGPL (PWT)
          call ler_arq2(unidade,pds5(11:11),f(:,11:11))
          where(f(:,11:11).eq.undef)lb(:,11:11) = .false.
          
          !Geopotencial
          call ler_arq2(unidade,pds5(12:14),f(:,12:14))
          where(f(:,12:14).eq.undef)lb(:,12:14) = .false.
         
          !Vento Zonal
          call ler_arq2(unidade,pds5(15:17),f(:,15:17))
          where(f(:,15:17).eq.undef)lb(:,15:17) = .false.

          !Vento Meridional
          call ler_arq2(unidade,pds5(18:20),f(:,18:20))
          where(f(:,18:20).eq.undef)lb(:,18:20) = .false.

			!endif
		
   

    !
    ! Convertendo as Variaveis para as utilizadas no scantec
    ! * A lista de variaveis e as unidades utilizadas podem ser
    !   obtidas no modulo scan_dataMOD.f90
    !

    allocate(f2(brams_struc%npts,scantec%nvar))
    !Conversões

    where(f(:,1) .gt. undef)
       es = 0.0
       ee = 0.0
       rv = 0.0
       es = 6.112*exp((17.67*f(:,1))/(f(:,1)+243.5))
       ee = f(:,8)*(es/100.0)
       rv = (0.622*ee)/(925.0-ee)
       f2(:,1) = f(:,1)*(1 + 0.61*rv)

       where(.not.lb(:,1).and..not.lb(:,8)) lb2(:,1) = .false.
    end where

    
    where(f(:,2) .gt. undef)
      es=0.
      ee=0.
      rv=0.
      es = 6.112*exp((17.67*f(:,2))/(f(:,2)+243.5))
      ee = f(:,9)*(es/100.0)
      rv = (0.622*ee)/(850.0-ee)
      f2(:,2) = f(:,2)*(1 + 0.61*rv)
				
      where(.not.lb(:,2).and..not.lb(:,9)) lb2(:,2) = .false.
   end where
				
   where(f(:,3) .gt. undef)
      es=0.
      ee=0.
      rv=0.
      es = 6.112*exp((17.67*f(:,3))/(f(:,3)+243.5))
      ee = f(:,10)*(es/100.0)
      rv = (0.622*ee)/(500.0-ee)
      f2(:,3) = f(:,3)*(1 + 0.61*rv)
      
      where(.not.lb(:,3).and..not.lb(:,10)) lb2(:,3) = .false.
   end where				
				
   where(f(:,4) .gt. undef)
      f2(:,4) = f(:,4)+273.15
      
      where(.not.lb(:,4))lb2(:,3) = .false.
   end where

   where(f(:,5) .gt. undef)
      f2(:,5) = f(:,5)+273.15
      
      where(.not.lb(:,5))lb2(:,5) = .false.
   end where
   
   where(f(:,6) .gt. undef)
      f2(:,6) = f(:,6)+273.15
      
      where(.not.lb(:,6))lb2(:,6) = .false.
   end where
				
   f2(:,7) = f(:,7)
   where(.not.lb(:,7))lb2(:,7) = .false.				

   where(f(:,8) .gt. undef)
      es=0.
      ee=0.
      rv=0.
      es = 6.112*exp((17.67*f(:,1))/(f(:,1)+243.5))
      ee = f(:,8)*(es/100.0)
      rv = (0.622*ee)/(925.0-ee)
      f2(:,8) = rv/(1+rv)
      
      where(.not.lb(:,8).and..not.lb(:,1)) lb2(:,8) = .false.
   end where
				
   where(f(:,9) .gt. undef)
      es=0.
      ee=0.
      rv=0.
      es = 6.112*exp((17.67*f(:,2))/(f(:,2)+243.5))
      ee = f(:,9)*(es/100.0)
      rv = (0.622*ee)/(850.0-ee)
      f2(:,9) = rv/(1+rv)
      
      where(.not.lb(:,9).and..not.lb(:,2)) lb2(:,9) = .false.
   end where
				
   where(f(:,10) .gt. undef)
      es=0.
      ee=0.
      rv=0.
      es = 6.112*exp((17.67*f(:,3))/(f(:,3)+243.5))
      ee = f(:,10)*(es/100.0)
      rv = (0.622*ee)/(500.0-ee)
      f2(:,10) = rv/(1+rv)
      
      where(.not.lb(:,10).and..not.lb(:,3)) lb2(:,10) = .false.
   end where				
				
   where(f(:,11) .gt. undef)
      f2(:,11) = f(:,11)*10.0

      where(.not.lb(:,11))lb2(:,11) = .false.
   end where     
    	
   f2(:,12) = f(:,12)
   where(.not.lb(:,12))lb2(:,12) = .false.
   
   f2(:,13) = f(:,13)
   where(.not.lb(:,13))lb2(:,13) = .false.
	     
   f2(:,14) = f(:,14)
   where(.not.lb(:,14))lb2(:,14) = .false.
   				
   f2(:,15) = f(:,15)
   where(.not.lb(:,15))lb2(:,15) = .false.
        
   f2(:,16) = f(:,16)
   where(.not.lb(:,16))lb2(:,16) = .false.
   
   f2(:,17) = f(:,17)
   where(.not.lb(:,17))lb2(:,17) = .false. 
       
   f2(:,18) = f(:,18)
   where(.not.lb(:,18))lb2(:,18) = .false.
   				
   f2(:,19) = f(:,19)
   where(.not.lb(:,19))lb2(:,19) = .false.
        
   f2(:,20) = f(:,20)
   where(.not.lb(:,20))lb2(:,20) = .false.

   else
      print*, "arquivo existe mas nao abre"
      stop
   endif
else
   print*, "File Not Found"
   stop
endif


    DeAllocate(lb)
    DeAllocate(f)
    
    DeAllocate(es)
    DeAllocate(ee)
    DeAllocate(rv)

    !
    ! padronizando pontos com undef
    !

    where(.not.lb2) f2 = scantec%udef

    !
    ! Interpolando para a grade do scantec
    !

    nx = int(scantec%gridDesc(2))
    ny = int(scantec%gridDesc(3))
    
    allocate(varfield(nx*ny))
    DO iv=1,scantec%nvar

       call interp_brams( kpds, brams_struc%npts,f2(:,iv),lb2(:,iv), scantec%gridDesc,&
                         scantec%nxpt,scantec%nypt, varfield, iret)    

    !
    ! Transferindo para matriz temporaria do scantec
    !

       scandata(1)%tmpfield(:,iv) = varfield(:)
       

    Enddo

    DeAllocate(varfield)

  END SUBROUTINE brams_read
!
!EOC
!
!-----------------------------------------------------------------------------!
!BOP
!
! !IROUTINE:  interp_brams
!
! !DESCRIPTION: this routine interpolates a givem field to the scantec domain 
!
!\\
!\\
! !INTERFACE:
!

  SUBROUTINE interp_brams( kpds, npts,f,lb,gridDesc, nxpt, nypt, field1d, iret)

!
! !INPUT PARAMETERS:
!

    integer, intent(in)   :: kpds(:)     ! grid deconding array information
    integer, intent(in)   :: npts        ! number of points in the input grid
    real, intent(out)     :: f(:)        ! input field to be interpolated
    logical*1, intent(in) :: lb(:)       ! input bitmap
    real, intent(in)      :: gridDesc(:) ! array description of the scantec grid
    integer, intent(in)   :: nxpt        ! number of columns (in the east-west dimension) in the scantec grid
    integer, intent(in)   :: nypt        ! number of rows (in the north-south dimension) in the scantec grid
!
! !OUTPUT PARAMETERS:
!
    real, intent(out)     :: field1d(:)
 ! output interpolated field

    integer, intent(out)  :: iret          ! error code

!
! !REVISION HISTORY: 
!  03 May 2012 - J. G. de Mattos - Initial Version
!
!
!EOP
!-----------------------------------------------------------------------------!
!BOC
!

    logical*1, dimension(nxpt,nypt) :: lo

    integer :: ip, ipopt(20),ibi,km
    integer :: ibo
    integer :: i,j,k
    character(len=*),parameter :: myname_=myname//'::interp_brams'

    !
    ! DEBUG print
    !

#ifdef DEBUG
    WRITE(stdout,'(     2A)')'Hello from ', myname_
#endif

    ip    = 0
    ipopt = 0
    km    = 1
    ibi   = 1
    lo    = .true.

    call bilinear_interp(gridDesc,ibi,lb,f,ibo,lo,field1d,   &
                         brams_struc%npts,nxpt*nypt,          &
                         brams_struc%rlat1, brams_struc%rlon1, &
                         brams_struc%w111, brams_struc%w121,   &
                         brams_struc%w211, brams_struc%w221,   &
                         brams_struc%n111, brams_struc%n121,   &
                         brams_struc%n211, brams_struc%n221,scantec%udef,iret)

    if (iret.ne.0)then
       call perr(myname_,'bilinear_interp ( ... ) ',iret)
       return
    endif

  END SUBROUTINE interp_brams
  

!
!EOC
!-----------------------------------------------------------------------------!

END MODULE m_brams
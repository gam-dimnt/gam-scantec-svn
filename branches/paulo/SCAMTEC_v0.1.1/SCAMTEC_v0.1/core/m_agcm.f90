!-----------------------------------------------------------------------------!
!           Group on Data Assimilation Development - GDAD/CPTEC/INPE          !
!-----------------------------------------------------------------------------!
!BOP
!
! !MODULE: m_agcm.f90
!
! !DESCRIPTON: This module contains routines and functions to configure,
!              read and interpolate fields of the model to use in SCAMTEC.
!                 
!\\
!\\
! !INTERFACE:
!

MODULE m_agcm

!
! !USES:
!
  USE scamtec_module                ! SCAMTEC types
  USE SCAM_dataMOD, only : scamdata ! SCAMTEC data matrix
  USE interp_mod                    ! Interpolation module
  USE m_die                         ! Error Messages
  USE m_stdio                       ! Module to defines std. I/O parameters


  IMPLICIT NONE
  PRIVATE
!
! !PUBLIC TYPES:  
!
  type agcm_type_dec 

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

  end type agcm_type_dec

  type(agcm_type_dec) :: agcm_struc
!
! !PUBLIC MEMBER FUNCTIONS:
!
  public :: agcm_read ! Function to read files from agcm model
  public :: agcm_init ! Function to initilize weights to interpolate fields
!
!
! !REVISION HISTORY:
!  03 May 2012 - J. G. de Mattos - Initial Version
!  06 May 2012 - J. G. de Mattos - Include new fields read
!  17 Oct 2012 - J. G. de Mattos - change UMES to g/kg
!
!
!
! !SEE ALSO:
!   
!
!EOP
!-----------------------------------------------------------------------------!
!
  character(len=*),parameter :: myname='m_agcm' 

CONTAINS
!
!-----------------------------------------------------------------------------!
!BOP
!
! !IROUTINE:  agcm_init
!
! !DESCRIPTION: This function initialize the matrices used to read 
!               and export fields to SCAMTEC
!\\
!\\
! !INTERFACE:
!

  SUBROUTINE agcm_init()

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
    character(len=*),parameter :: myname_=myname//'::agcm_init'

    !
    ! DEBUG print
    !

#ifdef DEBUG
    WRITE(stdout,'(     2A)')'Hello from ', myname_
#endif

    Allocate(agcm_struc%gridDesc(50))

    call agcm_domain()

    nx = int(scamtec%gridDesc(2))
    ny = int(scamtec%gridDesc(3))

    Allocate(agcm_struc%rlat1(nx*ny))
    Allocate(agcm_struc%rlon1(nx*ny))              
    Allocate(agcm_struc%n111(nx*ny))
    Allocate(agcm_struc%n121(nx*ny))
    Allocate(agcm_struc%n211(nx*ny))
    Allocate(agcm_struc%n221(nx*ny))
    Allocate(agcm_struc%w111(nx*ny))
    Allocate(agcm_struc%w121(nx*ny))
    Allocate(agcm_struc%w211(nx*ny))
    Allocate(agcm_struc%w221(nx*ny))

   !
   ! Initializing arrays of weights for interpolation in the field of SCAMTEC
   !

    call bilinear_interp_input(agcm_struc%gridDesc, scamtec%gridDesc,        &
                               int(scamtec%gridDesc(2)*scamtec%gridDesc(3)), &
                                     agcm_struc%rlat1,agcm_struc%rlon1,      &
                                     agcm_struc%n111,agcm_struc%n121,        &
                                     agcm_struc%n211,agcm_struc%n221,        &
                                     agcm_struc%w111,agcm_struc%w121,        &
                                     agcm_struc%w211,agcm_struc%w221)


  END SUBROUTINE agcm_init
!
!EOC
!
!-----------------------------------------------------------------------------!
!BOP
!
! !IROUTINE:  agcm_domain
!
! !DESCRIPTION: This routine initilize domain parameters of agcm model
!               
!\\
!\\
! !INTERFACE:
!

  SUBROUTINE agcm_domain()

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
    character(len=*),parameter :: myname_=myname//'::agcm_domain'

    !
    ! DEBUG print
    !

#ifdef DEBUG
    WRITE(stdout,'(     2A)')'Hello from ', myname_
#endif

    agcm_struc%gridDesc     = 0 

    agcm_struc%gridDesc( 1) = 4         !Input grid type (4=Gaussian)
    agcm_struc%gridDesc( 2) = 900       !Number of points on a lat circle
    agcm_struc%gridDesc( 3) = 450       !Number of points on a meridian
    agcm_struc%gridDesc( 4) = 89.69415  !Latitude of origin
    agcm_struc%gridDesc( 5) = 0.0       !Longitude of origin
    agcm_struc%gridDesc( 6) = 128       !8 bits (1 byte) related to resolution
                                        !(recall that 10000000 = 128), Table 7
    agcm_struc%gridDesc( 7) = -89.69415 !Latitude of extreme point
    agcm_struc%gridDesc( 8) = -0.400    !Longitude of extreme point
    agcm_struc%gridDesc( 9) = 0.400     !N/S direction increment
    agcm_struc%gridDesc(10) = 225       !(Gaussian) # lat circles pole-equator
    agcm_struc%gridDesc(20) = 0.0  

    agcm_struc%npts = agcm_struc%gridDesc(2)*agcm_struc%gridDesc(3)

  END SUBROUTINE agcm_domain
!
!EOC
!
!-----------------------------------------------------------------------------!
!BOP
!
! !IROUTINE:  agcm_read
!
! !DESCRIPTION: For a given file name, read fields from a agcm model,
!               interpolates to the SCAMTEC domain and export to SCAMTEC
!               matrices.                
!               
!\\
!\\
! !INTERFACE:
!

  SUBROUTINE agcm_read(fname)
    IMPLICIT NONE
!
! !INPUT PARAMETERS:
!
  
    character(len=*), intent(IN) :: fname ! File name of the agcm model

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
    character(len=*),parameter :: myname_=myname//'::agcm_read'

    integer :: iret, jret, gbret, stat
    logical :: file_exists
    integer :: jpds(200),jgds(200),gridDesc(200),kpds(200)
    integer :: lugb
    real    :: lubi
    real    :: kf,k
    integer :: i,j,iv
    integer :: npts
    integer :: nx
    integer :: ny
    integer, dimension(17) :: pds5, pds7
    logical*1, dimension(:,:), allocatable :: lb
    real, dimension(:,:), allocatable :: f
    real, dimension(:,:), allocatable :: f2
    real, dimension(:),   allocatable :: varfield


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
    !          Q   Q   Q   T   T   T   P   A   Z   Z   Z   U   U   U   V   V   V
    pds5 = (/ 51, 51, 51, 11, 11, 11,  2, 54,  7,  7,  7, 33, 33, 33, 34, 34, 34/) !parameter
    pds7 = (/925,850,500,925,850,500,000,000,850,500,250,850,500,250,850,500,250/) !htlev2

    allocate(lb(agcm_struc%npts,size(pds5)))
    allocate(f(agcm_struc%npts,size(pds5)))

    inquire (file=trim(fname), exist=file_exists)
    do iv = 1, size(pds5)

       if (file_exists) then 

          jpds(5) = pds5(iv)
          jpds(7) = pds7(iv)

          lugb    = lugb + iv

          call baopenr(lugb,fname,iret)

          if(iret.eq.0) then
             call getgb(lugb,lubi,agcm_struc%npts,j,jpds,jgds,kf,k,kpds, &
                  gridDesc,lb(:,iv),f(:,iv),gbret)

             if (gbret.ne.0)then
                stat = gbret
                call perr(myname_,'getgb("'//	  &
                          trim(fname)//'")',gbret &
                         )
                return
             endif

          else
             stat = iret
             call perr(myname_,'baopenr("'//	 &
                       trim(fname)//'")',iret &
                      )
             return
          endif

          call baclose(lugb,jret)
          if(jret.ne.0) then
            stat = jret
            call perr(myname_,'deallocate()',jret)
            return
	       endif
       else
          stat = -1

          deallocate(f)
          deallocate(lb)

	       call perr(myname_,'File Not Found: '//trim(fname),stat)
          return

       endif

    enddo

    !
    ! Convertendo as Variaveis para as utilizadas no SCAMTEC
    ! * A lista de variaveis e as unidades utilizadas podem ser
    !   obtidas no modulo SCAM_dataMOD.f90
    !

    allocate(f2(agcm_struc%npts,scamtec%nvar))

    f2(:, 1) = f(:, 4)*(1 + 0.61*(f(:,1)/(1-f(:,1)))) ! Vtmp @ 925 hPa [K]
    f2(:, 2) = f(:, 5)*(1 + 0.61*(f(:,2)/(1-f(:,2)))) ! Vtmp @ 850 hPa [K]
    f2(:, 3) = f(:, 6)*(1 + 0.61*(f(:,3)/(1-f(:,3)))) ! Vtmp @ 500 hPa [K]
    f2(:, 4) = f(:, 7)                                ! PSNM [hPa]
    f2(:, 5) = f(:, 1)*1000.0                         ! Umes @ 925 hPa [g/Kg]
    f2(:, 6) = f(:, 8)                                ! Agpl @ 925 hPa [Kg/m2]
    f2(:, 7) = f(:, 9)                                ! Zgeo @ 850 hPa [gpm]
    f2(:, 8) = f(:,10)                                ! Zgeo @ 500 hPa [gpm]
    f2(:, 9) = f(:,11)                                ! Zgeo @ 250 hPa [gpm]
    f2(:,10) = f(:,12)                                ! Uvel @ 850 hPa [m/s]
    f2(:,11) = f(:,13)                                ! Uvel @ 500 hPa [m/s]
    f2(:,12) = f(:,14)                                ! Uvel @ 250 hPa [m/s]
    f2(:,13) = f(:,15)                                ! Vvel @ 850 hPa [m/s]
    f2(:,14) = f(:,16)                                ! Vvel @ 500 hPa [m/s]
    f2(:,15) = f(:,17)                                ! Vvel @ 250 hPa [m/s]

    DeAllocate(f)

    !
    ! padronizando pontos com undef
    !
   
    where(.not.lb) f2 = scamtec%udef
    
    !
    ! Interpolando para a grade do SCAMTEC
    !

    nx = int(scamtec%gridDesc(2))
    ny = int(scamtec%gridDesc(3))
    
    allocate(varfield(nx*ny))

    DO iv=1,scamtec%nvar

       call interp_agcm( kpds, agcm_struc%npts,f2(:,iv),lb(:,iv), scamtec%gridDesc,&
                         scamtec%nxpt,scamtec%nypt, varfield, iret)    
    
    !
    ! Transferindo para matriz temporaria do SCAMTEC
    !

       scamdata(1)%tmpfield(:,iv) = varfield(:)


    Enddo

    DeAllocate(varfield)

  END SUBROUTINE agcm_read
!
!EOC
!
!-----------------------------------------------------------------------------!
!BOP
!
! !IROUTINE:  interp_agcm
!
! !DESCRIPTION: this routine interpolates a givem field to the SCAMTEC domain 
!
!\\
!\\
! !INTERFACE:
!

  SUBROUTINE interp_agcm( kpds, npts,f,lb,gridDesc, nxpt, nypt, field1d, iret)

!
! !INPUT PARAMETERS:
!

    integer, intent(in)   :: kpds(:)     ! grid deconding array information
    integer, intent(in)   :: npts        ! number of points in the input grid
    real, intent(out)     :: f(:)        ! input field to be interpolated
    logical*1, intent(in) :: lb(:)       ! input bitmap
    real, intent(in)      :: gridDesc(:) ! array description of the SCAMTEC grid
    integer, intent(in)   :: nxpt        ! number of columns (in the east-west dimension) in the SCAMTEC grid
    integer, intent(in)   :: nypt        ! number of rows (in the north-south dimension) in the SCAMTEC grid
!
! !OUTPUT PARAMETERS:
!
!    real, intent(out)     :: varfield(:,:) ! output interpolated field
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

!    real, dimension(nxpt*nypt) :: field1d
    logical*1, dimension(nxpt,nypt) :: lo

    integer :: ip, ipopt(20),ibi,km
    integer :: ibo
    integer :: i,j,k
    character(len=*),parameter :: myname_=myname//'::interp_agcm'

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
                         agcm_struc%npts,nxpt*nypt,          &
                         agcm_struc%rlat1, agcm_struc%rlon1, &
                         agcm_struc%w111, agcm_struc%w121,   &
                         agcm_struc%w211, agcm_struc%w221,   &
                         agcm_struc%n111, agcm_struc%n121,   &
                         agcm_struc%n211, agcm_struc%n221,scamtec%udef,iret)

    if (iret.ne.0)then
       call perr(myname_,'bilinear_interp ( ... ) ',iret)
       return
    endif

!    k = 0
!    do j = 1, nypt
!       do i = 1, nxpt
!          varfield(i,j) = field1d(i+k)
!       enddo
!       k = k + nxpt
!    enddo

  END SUBROUTINE interp_agcm
!
!EOC
!-----------------------------------------------------------------------------!

END MODULE m_agcm
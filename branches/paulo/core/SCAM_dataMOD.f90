!-----------------------------------------------------------------------------!
!           Group on Data Assimilation Development - GDAD/CPTEC/INPE          !
!-----------------------------------------------------------------------------!
!BOP
!
! !MODULE: SCAM_dataMOD.f90
!
! !DESCRIPTON:
!             
!                 
!\\
!\\
! !INTERFACE:
!

MODULE SCAM_dataMOD
!
! !USES:
!

  USE scamtec_module    ! SCAMTEC types
  USE m_string          ! String Manipulation
  USE SCAM_Utils, only: dom, nvmx, Refer, Clima, Exper, OBS
  USE SCAM_Utils, only: Precipitation_Flag,hist,Precip !Paulo Dias
  USE m_iwv
  
  IMPLICIT NONE
  PRIVATE

!
! !PARAMETERS:
!

  integer, public, Parameter :: NumVarAval = 22
  character(len=8), public, parameter ::   VarName(1:NumVarAval) = (/ &
                                           'VTMP-925',& ! Virtual Temperature @ 925 hPa [K]
                                           'VTMP-850',& ! Virtual Temperature @ 850 hPa [K]
                                           'VTMP-500',& ! Virtual Temperature @ 500 hPa [K]                                           
                                           'TEMP-850',& ! Absolute Temperature @ 850 hPa [K]             4 paulo dias
                                           'TEMP-500',& ! Absolute Temperature @ 500 hPa [K]		 5 paulo dias
                                           'TEMP-250',& ! Absolute Temperature @ 250 hPa [K]		 6 paulo dias                                           
                                           'PSNM-000',& ! Pressure reduced to MSL [hPa]                                           
                                           'UMES-925',& ! Specific Humidity @ 925 hPa [g/Kg]
                                           'UMES-850',& ! Specific Humidity @ 850 hPa [g/Kg]		 9 paulo dias
                                           'UMES-500',& ! Specific Humidity @ 500 hPa [g/Kg]		10 paulo dias                                           
                                           'AGPL-925',& ! Inst. Precipitable Water @ 925 hPa [Kg/m2]
                                           'ZGEO-850',& ! Geopotential height @ 850 hPa [gpm]
                                           'ZGEO-500',& ! Geopotential height @ 500 hPa [gpm]
                                           'ZGEO-250',& ! Geopotential height @ 250 hPa [gpm]
                                           'UVEL-850',& ! Zonal Wind @ 850 hPa [m/s]
                                           'UVEL-500',& ! Zonal Wind @ 500 hPa [m/s]
                                           'UVEL-250',& ! Zonal Wind @ 250 hPa [m/s]
                                           'VVEL-850',& ! Meridional Wind @ 850 hPa [m/s]
                                           'VVEL-500',& ! Meridional Wind @ 500 hPa [m/s]
                                           'VVEL-250',& ! Meridional Wind @  250 hPa [m/s]
                                           'PREC-000',& ! TOTAL PRECIPITATION @ 1000 hPa [kg/m2/day]           21 paulo dias
                                           'PREV-000' & ! CONVECTIVE PRECIPITATION @ 1000 hPa [kg/m2/day]      22 paulo dias
                                          /)

!
! !PUBLIC TYPES
!

  type model_dec_type
     real, allocatable :: tmpfield(:,:) ! data from model read
     real, allocatable :: expfield(:,:) ! experiment model field
     real, allocatable :: reffield(:,:) ! reference model field
     real, allocatable :: clmfield(:,:) ! climatology field
     real, allocatable :: prefield(:,:) ! preciptation field (paulo dias)
     real, allocatable :: obsfield(:,:) ! obs model field

     logical, allocatable :: UdfIdx (:,:)
!     real, allocatable :: diffield(:,:,:) ! diference field
!     real, allocatable :: rmsfield(:,:,:)
!     real, allocatable :: time_rmse(:,:)
!     real, allocatable :: time_vies(:,:)
!     real, allocatable :: time_acor(:,:)
  end type model_dec_type

  TYPE obs_dec_type
     real, allocatable :: tmpfield(:) ! data from model read
     real, allocatable :: expfield(:) ! experiment model field
     real, allocatable :: reffield(:) ! reference model field
     real, allocatable :: clmfield(:) ! climatology field
     real, allocatable :: prefield(:) ! preciptation field (paulo dias)
     real, allocatable :: diffield(:) ! diference field
     real, allocatable :: obsfield(:) ! obs model field
  END TYPE obs_dec_type

  public :: model_dec_type
  public :: obs_dec_type
  
  

!
! !PUBLIC DATA MEMBERS:
!

  type(model_dec_type), public, Target, allocatable :: scamdata(:)

!
! !PUBLIC MEMBER FUNCTIONS:
!

  public :: data_config
  public :: allocate_data_mem
  public :: data_init
  public :: ldata
  public :: SCAM_ModelData
  public :: SCAM_ObsData

!
! !REVISION HISTORY:
!  09 OCT 2011 - J. G. de Mattos - Initial Version
!     SEP 2012 - J. G. de Mattos - Include routine to read files
!  11 Oct 2012 - J. G. de Mattos - Remove bug at data_config routine.
!                                  Lat was being read inverted
!                                  dx and dy was inverted
!
! !SEE ALSO:
!   
!
!EOP
!-----------------------------------------------------------------------------!
!

CONTAINS

  SUBROUTINE data_config()
    IMPLICIT NONE
    integer :: I

    scamtec%gridDesc = 0

    scamtec%gridDesc( 1) = 0
    scamtec%gridDesc( 2) = dom(1)%nx        ! Number of x points
    scamtec%gridDesc( 3) = dom(1)%ny        ! number of y points
    scamtec%gridDesc( 4) = dom(1)%ll_lat    ! First latitude point (South point)
    scamtec%gridDesc( 5) = dom(1)%ll_lon    ! First longitude point (West point)
    scamtec%gridDesc( 6) = 128
    scamtec%gridDesc( 7) = dom(1)%ur_lat    ! Last latitude point (North Point)
    scamtec%gridDesc( 8) = dom(1)%ur_lon    ! Last longitude Point (East point)
    scamtec%gridDesc( 9) = dom(1)%dy        ! Delta y point
    scamtec%gridDesc(10) = dom(1)%dx        ! Delta x point
    scamtec%gridDesc(20) = 0

    scamtec%nxpt = dom(1)%nx
    scamtec%nypt = dom(1)%ny
    scamtec%npts = dom(1)%nx*dom(1)%ny

    scamtec%udef = -999.9

    scamtec%nvar = NumVarAval
    
    Allocate(scamtec%VarName(NumVarAval))
    scamtec%VarName = VarName

#ifdef DEBUG  
    write(6, FMT=123)'xdef',scamtec%nxpt,'linear', scamtec%gridDesc(5), scamtec%gridDesc(10)
    write(6, FMT=123)'ydef',scamtec%nypt,'linear', scamtec%gridDesc(4), scamtec%gridDesc(9)
123 FORMAT(A,1x,I4.3,1x,A,F9.3,F9.3)    
#endif


  END SUBROUTINE data_config



  SUBROUTINE allocate_data_mem()
    IMPLICIT NONE
    integer :: I

    allocate(scamdata(scamtec%NExp))

    allocate(scamdata(1)%reffield(scamtec%nxpt*scamtec%nypt,scamtec%nvar))
    allocate(scamdata(1)%tmpfield(scamtec%nxpt*scamtec%nypt,scamtec%nvar))
    allocate(scamdata(1)%obsfield(scamtec%nxpt*scamtec%nypt,scamtec%nvar))
    IF(scamtec%cflag.EQ.1)allocate(scamdata(1)%clmfield(scamtec%nxpt*scamtec%nypt,scamtec%nvar))
    IF(Precipitation_Flag.EQ.1)allocate(scamdata(1)%prefield(scamtec%nxpt*scamtec%nypt,scamtec%nvar))!paulo dias
    
    DO I=1,scamtec%NExp
       allocate(scamdata(I)%expfield(scamtec%nxpt*scamtec%nypt,scamtec%nvar))
       allocate(scamdata(I)%UdfIdx(scamtec%nxpt*scamtec%nypt,scamtec%nvar))
       
       
       !IF(Precipitation_Flag.EQ.1)allocate(scamdata(I)%time_histo(tam_hist,scamtec%ntime_forecast))!paulo dias
       
       
!      allocate(scamdata(I)%diffield(scamtec%nxpt,scamtec%nypt,scamtec%nvar))
!      allocate(scamdata(I)%rmsfield(scamtec%nxpt,scamtec%nypt,scamtec%nvar))
!      allocate(scamdata(I)%time_rmse(scamtec%ntime_forecast,scamtec%nvar))
!      allocate(scamdata(I)%time_vies(scamtec%ntime_forecast,scamtec%nvar))
!      allocate(scamdata(I)%time_acor(scamtec%ntime_forecast,scamtec%nvar))
    ENDDO


  END SUBROUTINE allocate_data_mem

  SUBROUTINE data_init()
    IMPLICIT NONE
    integer :: I

    DO I=1,scamtec%NExp

      scamdata(I)%UdfIdx    = .true.

!     scamdata(I)%diffield  = 0.0
!     scamdata(I)%rmsfield  = 0.0
!     scamdata(I)%time_rmse = 0.0
!     scamdata(I)%time_vies = 0.0
!     scamdata(I)%time_acor = 0.0

    ENDDO

  END SUBROUTINE

  SUBROUTINE release_data_mem()
    IMPLICIT NONE
    integer :: I

    IF (Allocated(scamdata(1)%reffield))DeAllocate(scamdata(1)%reffield)
    IF (Allocated(scamdata(1)%clmfield))DeAllocate(scamdata(1)%clmfield)
    IF (Allocated(scamdata(1)%tmpfield))DeAllocate(scamdata(1)%tmpfield)
    IF (Allocated(scamdata(I)%prefield))DeAllocate(scamdata(1)%prefield)!paulo dias
    IF (Allocated(scamdata(1)%obsfield))DeAllocate(scamdata(1)%obsfield)
     
    DO I=1,scamtec%NExp
       IF (Allocated(scamdata(I)%expfield))DeAllocate(scamdata(I)%expfield)
       IF (Allocated(scamdata(I)%UdfIdx))Deallocate(scamdata(I)%UdfIdx)

!      IF (Allocated(scamdata(I)%diffield))DeAllocate(scamdata(I)%diffield)
!      IF (Allocated(scamdata(I)%rmsfield))DeAllocate(scamdata(I)%rmsfield)
    ENDDO

  END SUBROUTINE release_data_mem


  SUBROUTINE ldata( type, e, Id, name )
    IMPLICIT NONE
    CHARACTER(LEN=*), INTENT(IN) :: type
    INTEGER,          INTENT(IN) :: Id
    INTEGER,          INTENT(IN) :: e
    CHARACTER(LEN=*), INTENT(IN) :: name
    INTEGER   :: stat
    INTEGER   :: I


    if (type .eq. 'O')then
       call loadobs_data(Id, name//char(0))
    else
       call load_data(Id, name//char(0))
    endif

#ifdef DEBUG  
    write(6,'(A,1x,A,1x,2F15.3)')                              &
                                 trim(type),': [MIN/MAX]::',   &
                                 minval(scamdata(1)%tmpfield,mask=scamdata(1)%tmpfield .ne. scamtec%udef), &
                                 maxval(scamdata(1)%tmpfield,mask=scamdata(1)%tmpfield .ne. scamtec%udef)
#endif

    !
    ! Definindo pontos onde nao calcular indices estatisticos
    !

    DO I=1,scamtec%nvar
       where (scamdata(1)%tmpfield(:,I) .eq. scamtec%udef) scamdata(e)%UdfIdx(:,I) = .false.
    ENDDO
    

    !
    ! Selecionando qual eh o campo que esta sendo lido
    !

    SELECT CASE(trim(type))
    CASE('R')
       scamdata(e)%reffield = scamdata(1)%tmpfield
    CASE('E')
       scamdata(e)%expfield = scamdata(1)%tmpfield
    CASE('C')
       scamdata(e)%clmfield = scamdata(1)%tmpfield
    CASE('P')       
       scamdata(e)%prefield = scamdata(1)%tmpfield !paulo dias
    CASE('O')
       scamdata(e)%obsfield = scamdata(1)%tmpfield
    END SELECT


  END SUBROUTINE ldata

  SUBROUTINE SCAM_ModelData( NExp )
     IMPLICIT NONE
     integer, intent(in) :: NExp
     integer             :: aymd, ahms
     integer             :: fymd, fhms
     character(len=1024) :: Reference    ! Reference File Name
     character(len=1024) :: Experiment   ! Experiment File Name
     character(len=1024) :: Climatology  ! Climatology File Name
     character(len=1024) :: Precipitation  ! Precipitation File Name (Paulo dias)
     
     

     aymd = scamtec%atime/100
     ahms = MOD(scamtec%atime,100) * 10000
     fymd = scamtec%ftime/100
     fhms = MOD(scamtec%ftime,100) * 10000

     !
     ! 1. Create file name and Open 
     !

!     if (scamtec%atime_flag)then

        !
        ! 1.1 Reference data file 
        !
	
        Reference=TRIM(Refer%file)
        CALL str_template(Reference, fymd,fhms)
        CALL ldata('R', 1, Refer%Id, Reference)

        !
        ! 1.2 Climatology data file
        !

     if (scamtec%atime_flag)then
      
        IF(scamtec%cflag.EQ.1)THEN
           Climatology=TRIM(Clima%file)
           CALL str_template(Climatology, fymd,fhms)
           CALL ldata('C', 1, Clima%Id, Climatology)
        END IF

        !
        ! 1.3 definindo flag = .false. para inibir a reabertura do arquivo de
        ! referencia e de climatologia para o mesmo tempo
        !

        scamtec%atime_flag = .false.

     endif

     !
     ! 1.3 Experiment Data File
     !
     
     !Joao adicionou para verificar quando nao tem o link das 0h
     Experiment = TRIM(Exper(NExp)%file)
     
     if (Exper(NExp)%id.eq.1.and.(scamtec%atime.eq.scamtec%ftime))then
        CALL replace_(Experiment, 'fct','icn')
     end if
     
     CALL str_template(Experiment, aymd, ahms, fymd, fhms)
     CALL ldata('E',NExp,Exper(NExp)%Id, Experiment)

     !
     ! 1.4 Precipitation data file 
     !
     IF(Precipitation_Flag .EQ. 1)THEN
     
        Precipitation=TRIM(Precip%file)
        CALL str_template(Precipitation, fymd,fhms)
        CALL ldata('P', 1, Precip%Id, Precipitation)
     END IF


  END SUBROUTINE

  SUBROUTINE SCAM_ObsData(  )
     
     IMPLICIT NONE
     

     	character(len=1024) :: observation
     	integer             :: aymd, ahms
     	integer             :: fymd, fhms
     	
#ifdef DEBUG
    WRITE(6,'(     2A)')'Entrando no OBSDATA do data mod '
#endif
 print*, 'o endereço do documento é : ', observation
     	observation=TRIM(OBS%file)
     	CALL str_template(observation, fymd,fhms)
     	CALL ldata('O', 1, OBS%Id, observation)
      	call iwv_init(observation)

  END SUBROUTINE SCAM_ObsData

END MODULE SCAM_dataMOD
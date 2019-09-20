! ============================================================================ !
!  Tracking Module
! ~~~~~~~~~~~~~~~~~
!  Module holding various routines used by the main tracking routines
! ============================================================================ !
module tracking

  use floatPrecision

  implicit none

  logical,           public,  save :: tr_is4D    = .false.
  logical,           public,  save :: tr_isThick = .false.
  character(len=8),  private, save :: trackMode  = " "
  character(len=32), private, save :: trackFmt   = " "
  integer,           private, save :: turnReport = 0

contains

! ================================================================================================ !
!  Prepare for Tracking
!  Code merged from old trauthin and trauthck routines
! ================================================================================================ !
subroutine preTracking

  use crcoall
  use mod_time
  use mod_common
  use mod_common_main
  use mod_common_track
  use numerical_constants
  use mathlib_bouncer

  use mod_particles, only : part_isTracking
  use collimation,   only : do_coll
  use mod_fluc,      only : fluc_writeFort4, fluc_errAlign
  use cheby,         only : cheby_kz, cheby_ktrack
  use dynk,          only : dynk_enabled, dynk_isused, dynk_pretrack
  use scatter,       only : scatter_elemPointer

  real(kind=fPrec) benkcc, r0, r000, r0a
  integer i, j, ix, jb, jx, kpz, kzz, nmz, oPart, oTurn

  tr_is4D    = idp == 0 .or. ition == 0
  tr_isThick = ithick == 1
  part_isTracking = .true.

  if(tr_isThick .and. do_coll) then
    write(lerr,"(a)") "TRACKING> ERROR Collimation is not supported for thick tracking"
    call prror
  end if

  ! Set up the tracking format for printout
  oPart = int(log10_mb(real(napxo, kind=fPrec))) + 1
  oTurn = int(log10_mb(real(numl,  kind=fPrec))) + 1
  write(trackFmt,"(2(a,i0),a)") "(2(a,i",oTurn,"),2(a,i",oPart,"))"

  if(numl > 1000) then
    turnReport = nint(numl/1000.0)
  else
    turnReport = 1
  end if

  do j=1,napx
    dpsv1(j) = (dpsv(j)*c1e3)/(one+dpsv(j))
  end do

  if(dynk_enabled) call dynk_pretrack
  call time_timeStamp(time_afterPreTrack)

  if(mout2 == 1) call fluc_writeFort4

  ! BEGIN Loop over structure elements
  do i=1,iu

    ix = ic(i) ! Single element index
    if(ix <= nblo) then
      ! This is a block element
      ktrack(i) = 1
      do jb=1,mel(ix)
        jx        = mtyp(ix,jb)
        strack(i) = strack(i)+el(jx)
      end do
      if(abs(strack(i)) <= pieni) then
        ktrack(i) = 31
      end if
      ! Non-linear/NOT BLOC
      cycle
    end if
    ix = ix-nblo ! Remove the block index offset

    if(mout2 == 1 .and. icextal(i) > 0) then
      write(27,"(a16,2x,1p,2d14.6,d17.9)") bez(ix),&
        fluc_errAlign(1,icextal(i)),fluc_errAlign(2,icextal(i)),fluc_errAlign(3,icextal(i))
    end if

    kpz = abs(kp(ix))
    if(kpz == 6) then
      ktrack(i) = 2
      cycle
    end if

    kzz = kz(ix)
    select case(kzz)

    case(0)
      ktrack(i) = 31

    case(13,14,17,18,19,21)
      cycle

    case(-10,-9,-8,-7,-6,-5,-4,-3,-2,-1,1,2,3,4,5,6,7,8,9,10)
      if(abs(smiv(i)) <= pieni .and. .not.dynk_isused(i)) then
        ktrack(i) = 31
      else
        if(kzz > 0) then
          ktrack(i) = 10 + kzz
        else
          ktrack(i) = 20 - kzz
        end if
        call setStrack(abs(kzz),i)
      end if

    case(12)
      ! Disabled cavity; enabled cavities have kp=6 and are handled above
      ! Note: kz=-12 are transformed into +12 in daten after reading ENDE.
      ktrack(i) = 31

    case(20) ! Beam-beam element
      call initialise_element(ix,.false.)

    case(15) ! Wire
      ktrack(i) = 45

    case(16) ! AC Dipole
      ktrack(i) = 51

    case(-16) ! AC Dipole
      ktrack(i) = 52

    case(22)
      ktrack(i) = 3

    case(23) ! Crab Cavity
      ktrack(i) = 53

    case(-23) ! Crab Cavity
      ktrack(i) = 54

    case(24) ! DIPEDGE ELEMENT
#include "include/stra2dpe.f90"
      ktrack(i) = 55

    case (25) ! Solenoid
#include "include/solenoid.f90"
      ktrack(i) = 56

    case(26) ! JBG RF CC Multipoles
      ktrack(i) = 57

    case(-26) ! JBG RF CC Multipoles
      ktrack(i) = 58

    case(27)
      ktrack(i) = 59

    case(-27)
      ktrack(i) = 60

    case(28)
      ktrack(i) = 61

    case(-28)
      ktrack(i) = 62

    case(29) ! Electron lens (HEL)
      ktrack(i) = 63

    case(cheby_kz) ! Chebyshev lens
      ktrack(i) = cheby_ktrack

    case(40) ! Scatter
      if(scatter_elemPointer(ix) /= 0) then
        ktrack(i) = 64 ! Scatter thin
      else
        ktrack(i) = 31
      end if

    case(41) ! RF Multipole
      ktrack(i) = 66
    case(43) ! X Rotation
      ktrack(i) = 68
    case(44) ! Y Rotation
      ktrack(i) = 69
    case(45) ! S Rotation
      ktrack(i) = 70

    case(11) ! Multipole block (also in initialise_element)
      r0  = ek(ix)
      nmz = nmu(ix)
      if(abs(r0) <= pieni .or. nmz == 0) then
        if(abs(dki(ix,1)) <= pieni .and. abs(dki(ix,2)) <= pieni) then
          if(dynk_isused(i)) then
            write(lerr,"(a)") "TRACKING> ERROR Element of type 11 (bez = '"//trim(bez(ix))//&
              "') is off in "//trim(fort2)//", but on in DYNK. Not implemented."
            call prror
          end if
          ktrack(i) = 31
        else if(abs(dki(ix,1)) > pieni .and. abs(dki(ix,2)) <= pieni) then
          if(abs(dki(ix,3)) > pieni) then
            ktrack(i) = 33 ! Horizontal Bend with a fictive length
            call setStrack(11,i)
          else
            ktrack(i) = 35 ! Horizontal Bend without a ficitve length
            call setStrack(12,i)
          end if
        else if(abs(dki(ix,1)) <= pieni.and.abs(dki(ix,2)) > pieni) then
          if(abs(dki(ix,3)) > pieni) then
            ktrack(i) = 37 ! Vertical bending with fictive length
            call setStrack(13,i)
          else
            ktrack(i) = 39 ! Vertical bending without fictive length
            call setStrack(14,i)
          end if
        end if
      else
        ! These are the same as above with the difference that they also will have multipoles associated with them.
        if(abs(dki(ix,1)) <= pieni .and. abs(dki(ix,2)) <= pieni) then
          ktrack(i) = 32
        else if(abs(dki(ix,1)) > pieni .and. abs(dki(ix,2)) <= pieni) then
          if(abs(dki(ix,3)) > pieni) then
            ktrack(i) = 34
            call setStrack(11,i)
          else
            ktrack(i) = 36
            call setStrack(12,i)
          end if
        else if(abs(dki(ix,1)) <= pieni .and. abs(dki(ix,2)) > pieni) then
          if(abs(dki(ix,3)) > pieni) then
            ktrack(i) = 38
            call setStrack(13,i)
          else
            ktrack(i) = 40
            call setStrack(14,i)
          end if
        end if
      end if
      if(abs(r0) <= pieni .or. nmz == 0) then
        cycle
      end if
      if(mout2 == 1) then
        benkcc = ed(ix)*benkc(irm(ix))
        r0a    = one
        r000   = r0*r00(irm(ix))

        do j=1,mmul
          fake(1,j) = (bbiv(j,i)*r0a)/benkcc
          fake(2,j) = (aaiv(j,i)*r0a)/benkcc
          r0a = r0a*r000
        end do

        write(9,"(a)") bez(ix)
        write(9,"(1p,3d23.15)") (fake(1,j), j=1,3)
        write(9,"(1p,3d23.15)") (fake(1,j), j=4,6)
        write(9,"(1p,3d23.15)") (fake(1,j), j=7,9)
        write(9,"(1p,3d23.15)") (fake(1,j), j=10,12)
        write(9,"(1p,3d23.15)") (fake(1,j), j=13,15)
        write(9,"(1p,3d23.15)") (fake(1,j), j=16,18)
        write(9,"(1p,2d23.15)") (fake(1,j), j=19,20)
        write(9,"(1p,3d23.15)") (fake(2,j), j=1,3)
        write(9,"(1p,3d23.15)") (fake(2,j), j=4,6)
        write(9,"(1p,3d23.15)") (fake(2,j), j=7,9)
        write(9,"(1p,3d23.15)") (fake(2,j), j=10,12)
        write(9,"(1p,3d23.15)") (fake(2,j), j=13,15)
        write(9,"(1p,3d23.15)") (fake(2,j), j=16,18)
        write(9,"(1p,2d23.15)") (fake(2,j), j=19,20)

        fake(1:2,1:20) = zero
      end if

    case default
      ktrack(i) = 31

    end select
  end do
  ! END Loop over structure elements

end subroutine preTracking

! ================================================================================================ !
!  Begin Tracking
!  Updated: 2019-09-20
! ================================================================================================ !
subroutine startTracking(nthinerr)

  use parpro
  use crcoall
  use mod_common
  use numerical_constants

  use collimation, only : do_coll
  use aperture,    only : lbacktracking, aperture_backTrackingInit

  integer, intent(inout) :: nthinerr

  integer i

  if(tr_is4D .eqv. .false.) then
    hsy(3)=(c1m3*hsy(3))*real(ition,fPrec)
    do i=1,nele
      if(abs(kz(i)) == 12) then
        hsyc(i) = (c1m3*hsyc(i)) * real(sign(1,kz(i)),kind=fPrec)
      end if
    end do
    if(abs(phas) >= pieni) then
      write(lerr,"(a)") "TRACKING> ERROR thin/thck6dua no longer supported. Please use DYNK instead."
      call prror
    end if
  end if

  nthinerr = 0
#ifdef FLUKA
    napxto = 0
#endif
  if(lbacktracking) call aperture_backTrackingInit

  if(ithick == 1) then
    if(idp == 0 .or. ition == 0) then
      write(lout,"(a)") ""
      write(lout,"(a)") "TRACKING> Starting Thick 4D Tracking"
      write(lout,"(a)") ""
      trackMode = "Thick 4D"
      call thck4d(nthinerr)
    else
      write(lout,"(a)") ""
      write(lout,"(a)") "TRACKING> Starting Thick 6D Tracking"
      write(lout,"(a)") ""
      trackMode = "Thick 6D"
      call thck6d(nthinerr)
    end if
  else
    if((idp == 0 .or. ition == 0) .and. .not.do_coll) then ! 4D tracking (not collimat compatible)
      write(lout,"(a)") ""
      write(lout,"(a)") "TRACKING> Starting Thin 4D Tracking"
      write(lout,"(a)") ""
      trackMode = "Thin 4D"
      call thin4d(nthinerr)
    else
      if(do_coll .and. (idp == 0 .or. ition == 0)) then ! Actually 4D, but collimation needs 6D so goto 6D.
        write(lout,"(a)") "TRACKING> WARNING Calling 6D tracking due to collimation! Would normally have called thin4d"
      endif
      write(lout,"(a)") ""
      write(lout,"(a)") "TRACKING> Starting Thin 6D Tracking"
      write(lout,"(a)") ""
      trackMode = "Thin 6D"
      call thin6d(nthinerr)
    end if
  end if

end subroutine startTracking

! ================================================================================================ !
!  V.K. Berglyd Olsen, BE-ABP-HSS
!  Updated: 2019-09-20
! ================================================================================================ !
subroutine trackReport(n)

  use crcoall
  use mod_common, only : numl, napx, napxo

  integer, intent(in) :: n

  if(mod(n,turnReport) == 0) then
    write(lout,trackFmt) "TRACKING> "//trim(trackMode)//": Turn ",n," / ",numl,", Particles: ",napx," / ",napxo
    flush(lout)
  end if

end subroutine trackReport

! ================================================================================================ !
!  F. Schmidt
!  Cretaed: 1999-02-03
! ================================================================================================ !
subroutine trackDistance

  use crcoall
  use mod_common
  use mod_common_main
  use floatPrecision
  use numerical_constants

  integer ia,ib2,ib3,ie,ip
  real(kind=fPrec) dam1

  do ip=1,(napxo+1)/2
    ia = pairMap(1,ip)
    ie = pairMap(2,ip)
    if(ia == 0 .or. ie == 0) then
      ! Check that the map does not contain a 0 index, which means something is wrong in the record keeping of lost particles
      write(lerr,"(a,i0)") "WRITEBIN> ERROR The map of particle pairs is missing one or both particles for pair ",ip
      call prror
    end if
    if(.not.pstop(ia) .and. .not.pstop(ie)) then
      dam(ia)  = zero
      dam(ie)  = zero
      xau(1,1) = xv1(ia)
      xau(1,2) = yv1(ia)
      xau(1,3) = xv2(ia)
      xau(1,4) = yv2(ia)
      xau(1,5) = sigmv(ia)
      xau(1,6) = dpsv(ia)
      xau(2,1) = xv1(ie)
      xau(2,2) = yv1(ie)
      xau(2,3) = xv2(ie)
      xau(2,4) = yv2(ie)
      xau(2,5) = sigmv(ie)
      xau(2,6) = dpsv(ie)
      cloau(1) = clo6v(1)
      cloau(2) = clop6v(1)
      cloau(3) = clo6v(2)
      cloau(4) = clop6v(2)
      cloau(5) = clo6v(3)
      cloau(6) = clop6v(3)
      di0au(1) = di0xs
      di0au(2) = dip0xs
      di0au(3) = di0zs
      di0au(4) = dip0zs
      tau(:,:) = tasau(:,:)

      call distance(xau,cloau,di0au,tau,dam1)
      dam(ia) = dam1
      dam(ie) = dam1
    end if
  end do

end subroutine trackDistance

! ================================================================================================ !
!  F. Schmidt
!  Cretaed: 1999-02-03
! ================================================================================================ !
subroutine trackPairReport(n)

  use crcoall
  use mod_common
  use mod_common_main
  use read_write
  use mod_settings

  integer ia,ig,n

  call writeFort12

  do ia=1,napxo,2
    ig=ia+1
#ifndef CR
#ifndef STF
    flush(91-(ig/2))
#else
    flush(90)
#endif
#endif
    !-- PARTICLES STABLE (Only if QUIET < 2)
    if(.not.pstop(ia).and..not.pstop(ig)) then
      if(st_quiet < 2) write(lout,10000) ia,izu0,dpsv(ia),n
      if(st_quiet < 1) write(lout,10010)                    &
        xv1(ia),yv1(ia),xv2(ia),yv2(ia),sigmv(ia),dpsv(ia), &
        xv1(ig),yv1(ig),xv2(ig),yv2(ig),sigmv(ig),dpsv(ig), &
        e0,ejv(ia),ejv(ig)
    end if
  end do
  return
10000 format(1x/5x,'PARTICLE ',i7,' RANDOM SEED ',i8,' MOMENTUM DEVIATION ',g12.5 /5x,'REVOLUTION ',i8/)
10010 format(10x,f47.33)
end subroutine trackPairReport

end module tracking

program fst240sim

! Generate simulated signals for experimental slow FT4  mode

   use wavhdr
   use packjt77
   include 'fst240_params.f90'               !Set various constants
   type(hdr) h                                !Header for .wav file
   character arg*12,fname*17
   character msg37*37,msgsent37*37,c77*77
   complex, allocatable :: c0(:)
   complex, allocatable :: c(:)
   real, allocatable :: wave(:)
   integer hmod
   integer itone(NN)
   integer*1 msgbits(101)
   integer*2, allocatable :: iwave(:)        !Generated full-length waveform

! Get command-line argument(s)
   nargs=iargc()
   if(nargs.ne.9) then
      print*,'Need 9 arguments, got ',nargs
      print*,'Usage:    fst240sim "message"        TRsec f0   DT  h fdop del nfiles snr'
      print*,'Examples: fst240sim "K1JT K9AN EN50"  60  1500 0.0  1  0.1 1.0   10   -15'
      go to 999
   endif
   call getarg(1,msg37)                   !Message to be transmitted
   call getarg(2,arg)
   read(arg,*) nsec                       !TR sequence length, seconds
   call getarg(3,arg)
   read(arg,*) f00                        !Frequency (only used for single-signal)
   call getarg(4,arg)
   read(arg,*) xdt                        !Time offset from nominal (s)
   call getarg(5,arg)
   read(arg,*) hmod                       !Modulation index, h
   call getarg(6,arg)
   read(arg,*) fspread                    !Watterson frequency spread (Hz)
   call getarg(7,arg)
   read(arg,*) delay                      !Watterson delay (ms)
   call getarg(8,arg)
   read(arg,*) nfiles                     !Number of files
   call getarg(9,arg)
   read(arg,*) snrdb                      !SNR_2500

   nfiles=abs(nfiles)
   twopi=8.0*atan(1.0)
   fs=12000.0                             !Sample rate (Hz)
   dt=1.0/fs                              !Sample interval (s)
   nsps=0
   if(nsec.eq.15) nsps=720
   if(nsec.eq.30) nsps=1680
   if(nsec.eq.60) nsps=3888
   if(nsec.eq.120) nsps=8200
   if(nsec.eq.300) nsps=21504
   if(nsps.eq.0) then
      print*,'Invalid TR sequence length.'
      go to 999
   endif
   baud=12000.0/nsps                      !Keying rate (baud)
   nmax=nsec*12000
   nz=nsps*NN
   nz2=nsps*NN2
   txt=nz2*dt                             !Transmission length (s)
   tt=nsps*dt                             !Duration of symbols (s)
   allocate( c0(0:nmax-1) )
   allocate( c(0:nmax-1) )
   allocate( wave(nmax) )
   allocate( iwave(nmax) )

   bandwidth_ratio=2500.0/(fs/2.0)
   sig=sqrt(2*bandwidth_ratio) * 10.0**(0.05*snrdb)
   if(snrdb.gt.90.0) sig=1.0

   i3=-1
   n3=-1
   call pack77(msg37,i3,n3,c77)
   call genfst240(msg37,0,msgsent37,msgbits,itone,iwspr)

   write(*,*)
   write(*,'(a9,a37)') 'Message: ',msgsent37
   write(*,1000) f00,xdt,hmod,txt,snrdb
1000 format('f0:',f9.3,'   DT:',f6.2,'   hmod:',i6,'   TxT:',f6.1,'   SNR:',f6.1)
   write(*,*)
   if(i3.eq.1) then
      write(*,*) '         mycall                         hiscall                    hisgrid'
      write(*,'(28i1,1x,i1,1x,28i1,1x,i1,1x,i1,1x,15i1,1x,3i1)') msgbits(1:77)
   else
      write(*,'(a14)') 'Message bits: '
      write(*,'(50i1,1x,24i1)') msgbits
   endif
   write(*,*)
   write(*,'(a17)') 'Channel symbols: '
   write(*,'(10i1)') itone
   write(*,*)

!   call sgran()

   fsample=12000.0
   icmplx=1
   f0=f00+1.5*hmod*baud
   call gen_fst240wave(itone,NN,nsps,nmax,fsample,hmod,f0,icmplx,c0,wave)
   k=nint((xdt+1.0)/dt)
   if(nsec.eq.15) k=nint((xdt+0.5)/dt)
   c0=cshift(c0,-k)
   if(k.gt.0) c0(0:k-1)=0.0
   if(k.lt.0) c0(nmax+k:nmax-1)=0.0

   do ifile=1,nfiles
      c=c0
      if(fspread.ne.0.0 .or. delay.ne.0.0) call watterson(c,nmax,NZ,fs,delay,fspread)
      c=sig*c
      wave=real(c)
      if(snrdb.lt.90) then
         do i=1,nmax                   !Add gaussian noise at specified SNR
            xnoise=gran()
            wave(i)=wave(i) + xnoise
         enddo
      endif
      gain=100.0
      if(snrdb.lt.90.0) then
         wave=gain*wave
      else
         datpk=maxval(abs(wave))
         fac=32766.9/datpk
         wave=fac*wave
      endif
      if(any(abs(wave).gt.32767.0)) print*,"Warning - data will be clipped."
      iwave=nint(wave)
      h=default_header(12000,nmax)
      if(nmax/12000.le.30) then
         write(fname,1102) ifile
1102     format('000000_',i6.6,'.wav')
      else
         write(fname,1104) ifile
1104     format('000000_',i4.4,'.wav')
      endif
      open(10,file=trim(fname),status='unknown',access='stream')
      write(10) h,iwave                !Save to *.wav file
      close(10)
      write(*,1110) ifile,xdt,f00,snrdb,fname
1110  format(i4,f7.2,f8.2,f7.1,2x,a17)
   enddo

999 end program fst240sim

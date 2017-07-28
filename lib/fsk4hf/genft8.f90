subroutine genft8(msg,mygrid,bcontest,msgsent,msgbits,itone)

! Encode an FT8 message, producing array itone().
  
  use crc
  use packjt
  include 'ft8_params.f90'
  character*22 msg,msgsent
  character*6 mygrid,g1,g2
  character*87 cbits
  logical*1 bcontest
  logical isgrid
  integer*4 i4Msg6BitWords(12)                !72-bit message as 6-bit words
  integer*1 msgbits(KK),codeword(3*ND)
  integer*1, target:: i1Msg8BitBytes(11)
  integer itone(NN)
  integer icos7(0:6)
  data icos7/2,5,6,0,4,1,3/                   !Costas 7x7 tone pattern

  isgrid(g1)=g1(1:1).ge.'A' .and. g1(1:1).le.'R' .and. g1(2:2).ge.'A' .and. &
       g1(2:2).le.'R' .and. g1(3:3).ge.'0' .and. g1(3:3).le.'9' .and.       &
       g1(4:4).ge.'0' .and. g1(4:4).le.'9' .and. g1(1:4).ne.'RR73'

  if(bcontest) then
     i0=index(msg,' R ') + 3                  !Check for ' R ' in message
     g1=msg(i0:i0+3)//'  '
     if(isgrid(g1)) then                      !Check for ' R grid'
        call grid2deg(g1,dlong,dlat)
        dlong=dlong+180.0
        if(dlong.gt.180.0) dlong=dlong-360.0
        dlat=-dlat
        call deg2grid(dlong,dlat,g2)          !g2=antipodes grid
        msg=msg(1:i0-3)//g2(1:4)              !Send message with g2
     endif
  endif

  call packmsg(msg,i4Msg6BitWords,itype)      !Pack into 12 6-bit bytes
  call unpackmsg(i4Msg6BitWords,msgsent)      !Unpack to get msgsent
  i3bit=0                                     !### temporary ###
  write(cbits,1000) i4Msg6BitWords,32*i3bit
1000 format(12b6.6,b8.8)
  read(cbits,1001) i1Msg8BitBytes(1:10)
1001 format(10b8)
  i1Msg8BitBytes(10)=iand(i1Msg8BitBytes(10),128+64+32)
  i1Msg8BitBytes(11)=0
  icrc12=crc12(c_loc(i1Msg8BitBytes),11)

! For reference, here's how to check the CRC
!  i1Msg8BitBytes(10)=icrc12/256
!  i1Msg8BitBytes(11)=iand (icrc12,255)
!  checksumok = crc12_check(c_loc (i1Msg8BitBytes), 11)
!  if( checksumok ) write(*,*) 'Good checksum'

  write(cbits,1003) i4Msg6BitWords,i3bit,icrc12
1003 format(12b6.6,b3.3,b12.12)
  read(cbits,1004) msgbits
1004 format(87i1)

  call encode174(msgbits,codeword)      !Encode the test message

! Message structure: S7 D29 S7 D29 S7
  itone(1:7)=icos7
  itone(36+1:36+7)=icos7
  itone(NN-6:NN)=icos7
  k=7
  do j=1,ND
     i=3*j -2
     k=k+1
     if(j.eq.30) k=k+7
     itone(k)=codeword(i)*4 + codeword(i+1)*2 + codeword(i+2)
  enddo

  return
end subroutine genft8

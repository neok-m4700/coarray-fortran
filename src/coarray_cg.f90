module conjugate_gradient

  ! import dependencies
  use iso_fortran_env, only : dp => REAL64

  implicit none

contains

  !-------------------------------------------------------------------!
  ! Solve the linear system using preconditioned conjugate gradient
  ! method
  !-------------------------------------------------------------------!
  
  subroutine dpparcg(A, M, b, max_it, max_tol, x, iter, tol, flag)

    use clock_class, only : clock

    real(dp), intent(in) :: A(:,:)
    real(dp), intent(in) :: M(:,:)
    real(dp), intent(in) :: b(:)
    integer , intent(in) :: max_it
    real(dp), intent(in) :: max_tol

    real(dp), intent(inout) :: x(:)
    integer , intent(out)   :: iter
    real(dp), intent(out)   :: tol
    integer , intent(out)   :: flag

    ! create local data
    real(dp), allocatable :: p(:), r(:), w(:), z(:)
    real(dp), allocatable :: rho(:), tau(:)
    real(dp) :: alpha, beta
    real(dp) :: bnorm, rnorm
    type(clock) :: timer

    ! Memory allocations
    allocate(r, p, w, z, mold=x)
    allocate(rho(max_it))
    allocate(tau(max_it))

    ! Start the iteration counter
    iter = 1

    ! Norm of the right hand side
    bnorm = co_norm2(b)

    ! Norm of the initial residual
    r         = b - co_matmul(A, x)
    rnorm     = co_norm2(r)
    tol       = rnorm/bnorm
    rho(iter) = rnorm*rnorm

    
    if (this_image() .eq. 1) then
       open(10, file='pcg.log', action='write', position='append')
    end if
    
    ! Apply Iterative scheme until tolerance is achieved
    do while ((tol .gt. max_tol) .and. (iter .lt. max_it))

       call timer % start()

       ! step (a)
       z = co_matmul(M,r)

       ! step (b)
       tau(iter) = co_dot_product(z,r)

       ! step (c) compute the descent direction
       if ( iter .eq. 1) then
          ! steepest descent direction p
          beta = 0.0d0
          p = z
       else
          ! take a conjugate direction
          beta = tau(iter)/tau(iter-1)
          p = z + beta*p
       end if

       ! step (b) compute the solution update
       w = co_matmul(A,p)

       ! step (c) compute the step size for update
       alpha = tau(iter)/co_dot_product(p, w)

       ! step (d) Add dx to the old solution
       x = x + alpha*p

       ! step (e) compute the new residual
       r = r - alpha*w
       !r = b - matmul(A, x)

       ! step(f) update values before next iteration
       rnorm = co_norm2(r)
       tol = rnorm/bnorm

       call timer % stop()
       
       if (this_image() .eq. 1) then
          write(10,*) iter, tol, timer % getelapsed()
          print *, iter, tol, timer % getelapsed()
       end if
       
       call timer % reset()
       
       iter = iter + 1

       rho(iter) = rnorm*rnorm

    end do

    close(10)

    deallocate(r, p, w, rho, tau)

    flag = 0

  end subroutine dpparcg
  
  subroutine dparcg(A, b, max_it, max_tol, x, iter, tol, flag)

    use clock_class, only : clock

    real(dp), intent(in) :: A(:,:)
    real(dp), intent(in) :: b(:)
    integer , intent(in) :: max_it
    real(dp), intent(in) :: max_tol

    real(dp), intent(inout) :: x(:)
    integer , intent(out)   :: iter
    real(dp), intent(out)   :: tol
    integer , intent(out)   :: flag

    ! create local data
    real(dp), allocatable :: p(:), r(:), w(:)
    real(dp), allocatable :: rho(:)
    real(dp) :: alpha, beta
    real(dp) :: bnorm, rnorm
    
    type(clock) :: timer
  
    ! Memory allocations
    allocate(r, p, w, mold=x)
    allocate(rho(max_it))

    ! Start the iteration counter
    iter = 1

    ! Norm of the right hand side
    bnorm = co_norm2(b)

    ! Norm of the initial residual
    r         = b - co_matmul(A, x)
    rnorm     = co_norm2(r)
    tol       = rnorm/bnorm
    rho(iter) = rnorm*rnorm

    if (this_image() .eq. 1) then
       open(10, file='cg.log', action='write', position='append')
    end if

    ! Apply Iterative scheme until tolerance is achieved
    do while ((tol .gt. max_tol) .and. (iter .lt. max_it))

       call timer % start()
       
       ! step (a) compute the descent direction
       if ( iter .eq. 1) then
          ! steepest descent direction p
          p = r
       else
          ! take a conjugate direction
          beta = rho(iter)/rho(iter-1)
          p = r + beta*p
       end if

       ! step (b) compute the solution update
       w = co_matmul(A,p)

       ! step (c) compute the step size for update
       alpha = rho(iter)/co_dot_product(p, w)

       ! step (d) Add dx to the old solution
       x = x + alpha*p

       ! step (e) compute the new residual
       r = r - alpha*w
       !r = b - matmul(A, x)

       ! step(f) update values before next iteration
       rnorm = co_norm2(r)
       tol = rnorm/bnorm

       call timer % stop()

       
       if (this_image() .eq. 1) then
          write(10,*) iter, tol, timer % getelapsed()
          print *, iter, tol, timer % getelapsed()
       end if
       
       call timer % reset()
       
       iter = iter + 1

       rho(iter) = rnorm*rnorm

    end do

    close(10)

    deallocate(r, p, w, rho)

    flag = 0

  end subroutine dparcg

  !===================================================================!
  ! Function to compute the dot product of two distributed vector
  !===================================================================!

  function co_dot_product(a, b) result(dot)

    real(8), intent(in) :: a(:), b(:)    
    real(8) :: dot

    ! find dot product, sum over processors, take sqrt and return
    dot = dot_product(a, b)  
    call co_sum (dot)

  end function co_dot_product

  !===================================================================!
  ! Function to compute the norm of a distributed vector
  !===================================================================!

  function co_norm2(x) result(norm)

    real(8), intent(in) :: x(:)    
    real(8) :: xdot, norm

    ! find dot product, sum over processors, take sqrt and return
    xdot = dot_product(x,x)  
    call co_sum (xdot)
    norm = sqrt(xdot)

  end function co_norm2

  !===================================================================!
  ! Function that computes the matrix vector product in a distributed
  ! fashion for columnwise decomposition of matrix
  ! ===================================================================!

  function co_matmul(A, x) result(b)

    ! Arguments
    real(8), intent(in) :: A(:,:)
    real(8), intent(in) :: x(:)
    real(8) :: b(size(x))

    ! Local variables
    integer :: nimages
    integer :: me, local_size
    integer :: stat
    character(10) :: msg

    ! Create a local vector of global sizse (optimize this!)
    real(8), allocatable :: work(:)
    allocate(work, mold=A(:,1))

    ! Determine partition
    nimages = num_images()
    me = this_image()
    local_size = size(x)

    ! Multiply, sum and distrbute
    work = matmul(A,x)
    call co_sum(work, stat=stat, errmsg=msg)
    b = work((me-1)*local_size+1:me*local_size)

    deallocate(work)

  end function co_matmul

end module conjugate_gradient

module system

  implicit none

contains

  !-------------------------------------------------------------------!
  ! Assemble -U_xx = 2x - 0.5, U(0) = 1;  U(1)= 0, x in [0,1]
  !-------------------------------------------------------------------!

  subroutine assemble_system_dirichlet(a, b, npts, V, rhs, u, P, ispreconditioned)

    implicit none

    real(8), intent(in)  :: a, b ! bounds of the domain
    integer, intent(in)  :: npts ! number of interior points
    real(8), intent(out) :: V(npts,npts) ! banded matrix
    real(8), intent(out) :: rhs(npts)
    real(8), intent(out) :: u(npts)
    real(8), intent(out) :: P(npts,npts)
    real(8) :: S(npts,npts), D(npts, npts)

    real(8), parameter :: PI = 3.141592653589793d0
    real(8)            :: h, alpha
    integer            :: M, N
    integer            :: i, j, k

    logical, intent(in) :: ispreconditioned
    
    ! h = width / num_interior_pts + 1
    h = (b-a)/dble(npts+1)
    V = 0.0d0

    ! Size of the linear system = unknowns (interior nodes)
    M = npts ! nrows
    N = npts ! ncols

    ! Set the inner block
    rows: do i = 1, M
       cols: do j = 1, N
          if (j .eq. i-1) then
             ! lower triangle
             V(j,i) = -1.0d0
          else if (j .eq. i+1) then           
             ! upper triangle
             V(j,i) = -1.0d0
          else if (j .eq. i) then           
             ! diagonal
             V(j,i) = 2.0d0
          else
             ! skip
          end if
       end do cols
    end do rows

    ! Assemble the RHS
    do i = 1, M
       rhs(i) = h*h*(2.0d0*dble(i)*h - 0.5d0)
    end do
    rhs(1) = rhs(1) + 1.0d0
    rhs(M) = rhs(M)

    ! Initial solution profile use sin function as a first guess
    do i = 1, M
       u(i) =  sin(dble(i)*h*PI)
    end do

    if (ispreconditioned .eqv. .true.) then
       ! Find the sine transform matrix
       alpha = sqrt(2.0d0/dble(npts+1))
       do j = 1, M
          do k = 1, N
             S(k,j) = alpha*sin(PI*dble(j*k)/dble(npts+1))
          end do
       end do

       ! Find the diagonal matrix
       D = matmul(S, matmul(V, S))

       ! Invert the digonal matrix easily
       do j = 1, M
          D(j,j) = 1.0d0/D(j,j)
       end do

       ! Define the preconditioner
       p = matmul(S, matmul(D, S))
    end if

end subroutine assemble_system_dirichlet

end module system

program main

  use conjugate_gradient, only: dparcg, dpparcg
  use system, only : assemble_system_dirichlet
  use clock_class, only : clock

!!$  serial : block
!!$    
!!$    integer, parameter :: npts = 64
!!$    real(8), parameter :: max_tol = 1.0d-8
!!$    integer, parameter :: max_it = 100000
!!$    real(8) :: x(npts,3), b(npts), A(npts,npts), P(npts, npts)
!!$    integer :: iter, flag, i, j
!!$    real(8) :: tol
!!$
!!$    ! solve using CG
!!$    call assemble_system_dirichlet(0.0d0, 1.0d0, npts, A, b, x(:,2), P) 
!!$    call dparcg(A, b, max_it, max_tol, x(:,2), iter, tol, flag)
!!$    print *, 'cg', tol, iter
!!$
!!$  end block serial

  parallel : block

    integer, parameter :: npts = 25000
    integer, parameter :: max_it = 1000
    real(8), parameter :: max_tol = 1.0d-8

    real(8), allocatable :: x(:)[:], b(:)[:], A(:,:)[:], P(:,:)[:]
    real(8), allocatable :: xtmp(:), btmp(:), Atmp(:,:), Ptmp(:,:)

    integer :: iter, flag, i, j
    real(8) :: tol   
    integer :: nimages
    integer :: me, local_size
    type(clock) :: timer
    logical , parameter :: precon = .false.
    
    allocate(A(npts,npts)[*])
    allocate(P(npts,npts)[*])
    allocate(x(npts)[*])
    allocate(b(npts)[*])

    ! Determine partition
    nimages    = num_images()
    me         = this_image()
    local_size = npts/nimages

    ! Assemble system on master
    if (me .eq. 1) then
       call assemble_system_dirichlet(0.0d0, 1.0d0, npts, A, b, x, P, precon)
    end if

    !sync all
    
    call timer % start()

    ! Split A, b, x into pieces
    allocate(Atmp(npts,local_size))
    allocate(Ptmp(npts,local_size))
    allocate(xtmp(local_size))
    allocate(btmp(local_size))

    
    ! Copy from proc 1
    Atmp = A(1:npts,(me-1)*local_size+1:me*local_size)[1]
    Ptmp = P(1:npts,(me-1)*local_size+1:me*local_size)[1]
    xtmp = x((me-1)*local_size+1:me*local_size)[1]
    btmp = b((me-1)*local_size+1:me*local_size)[1]

    ! clearup memory
    deallocate(A,b,x,P)

    ! Distribute the work to processors

    if (precon .eqv. .false.) then
       call dparcg(Atmp, btmp, max_it, max_tol, xtmp, iter, tol, flag)
    else
       call dpparcg(Atmp, Ptmp, btmp, max_it, max_tol, xtmp, iter, tol, flag)
    end if
    
    call timer % stop()

    if (this_image() .eq. 1) then
       write(*, '("Model run time:",F8.3," seconds")') timer % getelapsed()
    end if

    !if (me .eq. 1) then
    print *, 'cg', tol, iter
    
    !end if

  end block parallel

end program main

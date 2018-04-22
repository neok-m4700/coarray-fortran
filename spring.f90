module element_class

  implicit none

  private
  
  public :: spring
  
  type :: spring

     ! Unique global identifier for this element
     integer :: element_id

     ! Global node identifiers associated with this element
     integer              :: nnodes
     integer, allocatable :: node_ids(:)
     real(8), allocatable :: nodes(:,:)

     ! DOF calculations
     integer :: ndof_per_node = 1
     integer :: ndof = 0

     real(8) :: k = 1.0d0

     integer :: proc_id
     
   contains

     procedure :: add_residual
     procedure :: add_jacobian_vector_pdt
     procedure :: to_string
     
  end type spring

  ! Constructor
  interface spring
     module procedure construct_spring
  end interface spring
  
contains

  !===================================================================!
  ! Constructor for spring
  !===================================================================!

  pure type(spring) function construct_spring( element_id, node_ids, &
       & nodes, proc_id ) result (this)

    integer, intent(in) :: element_id
    integer, intent(in) :: node_ids(:)
    real(8), intent(in) :: nodes(:,:)
    integer, intent(in) :: proc_id

    this % element_id = element_id
    this % node_ids = node_ids
    this % nodes = nodes
    this % proc_id = proc_id

  end function construct_spring
  
  !===================================================================!
  ! Print object info
  !===================================================================!
  
  subroutine to_string(this)

    class(spring) :: this

    print *, "eid", this % element_id,  "nids", this % node_ids, "x", this % nodes, "proc", this % proc_id
    
  end subroutine to_string

  !===================================================================!
  ! Add the residual 
  !===================================================================!

  subroutine add_residual(this, res, x)

    class(spring) :: this
    real(8), intent(in) :: x(:)
    real(8), intent(inout) :: res(:)

    ! use forces may be?
    res(1) = this % k * x(1) - 1.0d0 
    
  end subroutine add_residual

  !===================================================================!
  ! Add the jacobian
  !===================================================================!

  subroutine add_jacobian_vector_pdt(this, jac, x)

    class(spring) :: this
    real(8), intent(in) :: x(:)
    real(8), intent(inout) :: jac(:,:)

    jac(1,1) = this % k
    
  end subroutine add_jacobian_vector_pdt

end module element_class

program main

  use element_class, only : spring
  
  implicit none

  ! Domain and meshing
  real(8), parameter :: a = 0.0d0, b = 1.0d0
  integer, parameter :: nelems = 100

  integer :: nnodes = nelems + 1
  integer :: me, nimages
  !real(8) :: la, lb
  real(8) :: dx

  type(spring), allocatable :: springs(:)
  integer :: lnelems
  integer :: e
  integer :: leid
  integer :: lnode_ids(2)
  real(8) :: lnodes(2, 1) = 0.0d0

  ! Mesh sizse
  dx = (b-a)/dble(nelems)
  
  ! Identify processors
  me = this_image()
  nimages = num_images()
  if (nimages .gt. nelems) STOP "Too many processors for the problem size"
  if ( mod(nelems, nimages) .ne. 0) STOP "Unequal partition. Use different number of processors."

  ! Decompose domain based on procs
  lnelems = nelems/nimages
  !la = dble(me-1)*ldx
  !lb = la + ldx
  
  ! Allocate the elements locally on each processor
  allocate(springs(lnelems))
  
  ! Mesh the local domain
  do e = 1, lnelems

     leid        = (me-1)*lnelems + e
     lnode_ids   = [leid, leid + 1]
     lnodes(:,1) = [dble(lnode_ids - 1)*dx]

     !print *, lnodes
     springs(e) = spring(leid, lnode_ids, lnodes, me)

     call springs(e) % to_string()
     
  end do



  ! 


  
  deallocate(springs)
  
end program main
!--------------------------------------------------------------------------------------------------!
!   CP2K: A general program to perform molecular dynamics simulations                              !
!   Copyright (C) 2000 - 2020  CP2K developers group                                               !
!--------------------------------------------------------------------------------------------------!

! **************************************************************************************************
!> \brief Fortran API for the grid package, which is written in C.
!> \author Ole Schuett
! **************************************************************************************************
MODULE grid_api
   USE ISO_C_BINDING,                   ONLY: C_ASSOCIATED,&
                                              C_BOOL,&
                                              C_DOUBLE,&
                                              C_F_POINTER,&
                                              C_INT,&
                                              C_LOC,&
                                              C_NULL_PTR,&
                                              C_PTR
   USE cell_types,                      ONLY: cell_type
   USE cp_log_handling,                 ONLY: cp_logger_get_default_io_unit
   USE cube_utils,                      ONLY: cube_info_type
   USE grid_collocate,                  ONLY: &
        GRID_FUNC_AB, GRID_FUNC_ADBmDAB_X, GRID_FUNC_ADBmDAB_Y, GRID_FUNC_ADBmDAB_Z, &
        GRID_FUNC_ARDBmDARB_XX, GRID_FUNC_ARDBmDARB_XY, GRID_FUNC_ARDBmDARB_XZ, &
        GRID_FUNC_ARDBmDARB_YX, GRID_FUNC_ARDBmDARB_YY, GRID_FUNC_ARDBmDARB_YZ, &
        GRID_FUNC_ARDBmDARB_ZX, GRID_FUNC_ARDBmDARB_ZY, GRID_FUNC_ARDBmDARB_ZZ, &
        GRID_FUNC_DABpADB_X, GRID_FUNC_DABpADB_Y, GRID_FUNC_DABpADB_Z, GRID_FUNC_DADB, &
        GRID_FUNC_DX, GRID_FUNC_DXDX, GRID_FUNC_DXDY, GRID_FUNC_DY, GRID_FUNC_DYDY, &
        GRID_FUNC_DYDZ, GRID_FUNC_DZ, GRID_FUNC_DZDX, GRID_FUNC_DZDZ, &
        collocate_pgf_product_legacy => collocate_pgf_product
   USE grid_integrate,                  ONLY: integrate_pgf_product
   USE kinds,                           ONLY: dp
   USE realspace_grid_types,            ONLY: realspace_grid_p_type,&
                                              realspace_grid_type
#include "../base/base_uses.f90"

   IMPLICIT NONE

   PRIVATE

   CHARACTER(len=*), PARAMETER, PRIVATE :: moduleN = 'grid_api'

   LOGICAL, PARAMETER, PRIVATE :: validate_collocate = .FALSE.

   PUBLIC :: GRID_FUNC_AB
   PUBLIC :: GRID_FUNC_DADB
   PUBLIC :: GRID_FUNC_ADBmDAB_X
   PUBLIC :: GRID_FUNC_ADBmDAB_Y
   PUBLIC :: GRID_FUNC_ADBmDAB_Z
   PUBLIC :: GRID_FUNC_ARDBmDARB_XX
   PUBLIC :: GRID_FUNC_ARDBmDARB_XY
   PUBLIC :: GRID_FUNC_ARDBmDARB_XZ
   PUBLIC :: GRID_FUNC_ARDBmDARB_YX
   PUBLIC :: GRID_FUNC_ARDBmDARB_YY
   PUBLIC :: GRID_FUNC_ARDBmDARB_YZ
   PUBLIC :: GRID_FUNC_ARDBmDARB_ZX
   PUBLIC :: GRID_FUNC_ARDBmDARB_ZY
   PUBLIC :: GRID_FUNC_ARDBmDARB_ZZ
   PUBLIC :: GRID_FUNC_DABpADB_X
   PUBLIC :: GRID_FUNC_DABpADB_Y
   PUBLIC :: GRID_FUNC_DABpADB_Z
   PUBLIC :: GRID_FUNC_DX
   PUBLIC :: GRID_FUNC_DY
   PUBLIC :: GRID_FUNC_DZ
   PUBLIC :: GRID_FUNC_DXDY
   PUBLIC :: GRID_FUNC_DYDZ
   PUBLIC :: GRID_FUNC_DZDX
   PUBLIC :: GRID_FUNC_DXDX
   PUBLIC :: GRID_FUNC_DYDY
   PUBLIC :: GRID_FUNC_DZDZ

   PUBLIC :: collocate_pgf_product, integrate_pgf_product
   PUBLIC :: grid_basis_set_type, grid_create_basis_set, grid_free_basis_set
   PUBLIC :: grid_task_list_type, grid_create_task_list, grid_free_task_list
   PUBLIC :: grid_collocate_task_list

   TYPE grid_basis_set_type
      PRIVATE
      TYPE(C_PTR) :: c_ptr = C_NULL_PTR
   END TYPE grid_basis_set_type

   TYPE grid_task_list_type
      PRIVATE
      TYPE(C_PTR) :: c_ptr = C_NULL_PTR
   END TYPE grid_task_list_type

CONTAINS

! **************************************************************************************************
!> \brief low level collocation of primitive gaussian functions
!> \param la_max ...
!> \param zeta ...
!> \param la_min ...
!> \param lb_max ...
!> \param zetb ...
!> \param lb_min ...
!> \param ra ...
!> \param rab ...
!> \param scale ...
!> \param pab ...
!> \param o1 ...
!> \param o2 ...
!> \param rsgrid ...
!> \param cell ...
!> \param cube_info ...
!> \param ga_gb_function ...
!> \param radius ...
!> \param use_subpatch ...
!> \param subpatch_pattern ...
!> \author Ole Schuett
! **************************************************************************************************
   SUBROUTINE collocate_pgf_product(la_max, zeta, la_min, &
                                    lb_max, zetb, lb_min, &
                                    ra, rab, scale, pab, o1, o2, &
                                    rsgrid, cell, cube_info, &
                                    ga_gb_function, radius, &
                                    use_subpatch, subpatch_pattern)

      INTEGER, INTENT(IN)                                :: la_max
      REAL(KIND=dp), INTENT(IN)                          :: zeta
      INTEGER, INTENT(IN)                                :: la_min, lb_max
      REAL(KIND=dp), INTENT(IN)                          :: zetb
      INTEGER, INTENT(IN)                                :: lb_min
      REAL(KIND=dp), DIMENSION(3), INTENT(IN), TARGET    :: ra, rab
      REAL(KIND=dp), INTENT(IN)                          :: scale
      REAL(KIND=dp), DIMENSION(:, :), POINTER            :: pab
      INTEGER, INTENT(IN)                                :: o1, o2
      TYPE(realspace_grid_type)                          :: rsgrid
      TYPE(cell_type), POINTER                           :: cell
      TYPE(cube_info_type), INTENT(IN)                   :: cube_info
      INTEGER, INTENT(IN)                                :: ga_gb_function
      REAL(KIND=dp), INTENT(IN)                          :: radius
      LOGICAL, OPTIONAL                                  :: use_subpatch
      INTEGER, INTENT(IN), OPTIONAL                      :: subpatch_pattern

      INTEGER                                            :: border_mask, i, iw, j, k, my_pos
      INTEGER, DIMENSION(3), TARGET                      :: border_width, npts_global, npts_local, &
                                                            shift_local
      INTEGER, SAVE                                      :: counter = 0
      LOGICAL(KIND=C_BOOL)                               :: orthorhombic
      REAL(KIND=dp)                                      :: diff, ref_value, rel_diff, tolerance
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER         :: grid, grid_before
      INTERFACE
         SUBROUTINE grid_collocate_pgf_product_cpu(orthorhombic, &
                                                   border_mask, func, &
                                                   la_max, la_min, lb_max, lb_min, &
                                                   zeta, zetb, rscale, dh, dh_inv, ra, rab, &
                                                   npts_global, npts_local, shift_local, border_width, &
                                                   radius, o1, o2, n1, n2, pab, &
                                                   grid) &
            BIND(C, name="grid_collocate_pgf_product_cpu")
            IMPORT :: C_PTR, C_INT, C_DOUBLE, C_BOOL
            LOGICAL(KIND=C_BOOL), VALUE               :: orthorhombic
            INTEGER(KIND=C_INT), VALUE                :: border_mask
            INTEGER(KIND=C_INT), VALUE                :: func
            INTEGER(KIND=C_INT), VALUE                :: la_max
            INTEGER(KIND=C_INT), VALUE                :: la_min
            INTEGER(KIND=C_INT), VALUE                :: lb_max
            INTEGER(KIND=C_INT), VALUE                :: lb_min
            REAL(KIND=C_DOUBLE), VALUE                :: zeta
            REAL(KIND=C_DOUBLE), VALUE                :: zetb
            REAL(KIND=C_DOUBLE), VALUE                :: rscale
            TYPE(C_PTR), VALUE                        :: dh
            TYPE(C_PTR), VALUE                        :: dh_inv
            TYPE(C_PTR), VALUE                        :: ra
            TYPE(C_PTR), VALUE                        :: rab
            TYPE(C_PTR), VALUE                        :: npts_global
            TYPE(C_PTR), VALUE                        :: npts_local
            TYPE(C_PTR), VALUE                        :: shift_local
            TYPE(C_PTR), VALUE                        :: border_width
            REAL(KIND=C_DOUBLE), VALUE                :: radius
            INTEGER(KIND=C_INT), VALUE                :: o1
            INTEGER(KIND=C_INT), VALUE                :: o2
            INTEGER(KIND=C_INT), VALUE                :: n1
            INTEGER(KIND=C_INT), VALUE                :: n2
            TYPE(C_PTR), VALUE                        :: pab
            TYPE(C_PTR), VALUE                        :: grid
         END SUBROUTINE grid_collocate_pgf_product_cpu
      END INTERFACE

      !TODO remove unused dummy arguments
      MARK_USED(cell)
      MARK_USED(cube_info)

      border_mask = 0
      IF (PRESENT(use_subpatch)) THEN
         IF (use_subpatch) THEN
            CPASSERT(PRESENT(subpatch_pattern))
            border_mask = IAND(63, NOT(subpatch_pattern))  ! invert last 6 bits
         END IF
      END IF

      orthorhombic = LOGICAL(rsgrid%desc%orthorhombic, C_BOOL)

      CPASSERT(LBOUND(pab, 1) == 1)
      CPASSERT(LBOUND(pab, 2) == 1)

      CALL get_rsgrid_properties(rsgrid, npts_global=npts_global, &
                                 npts_local=npts_local, &
                                 shift_local=shift_local, &
                                 border_width=border_width)

      IF (validate_collocate) THEN
         ALLOCATE (grid(SIZE(rsgrid%r, 1), SIZE(rsgrid%r, 2), SIZE(rsgrid%r, 3)))
         ALLOCATE (grid_before(SIZE(rsgrid%r, 1), SIZE(rsgrid%r, 2), SIZE(rsgrid%r, 3)))
         grid_before = rsgrid%r ! copy
         grid = 0.0_dp
         rsgrid%r = 0.0_dp
      ELSE
         grid(1:, 1:, 1:) => rsgrid%r(:, :, :)  ! pointer assignment
      ENDIF

#if __GNUC__ >= 9
      CPASSERT(IS_CONTIGUOUS(rsgrid%desc%dh))
      CPASSERT(IS_CONTIGUOUS(rsgrid%desc%dh_inv))
      CPASSERT(IS_CONTIGUOUS(ra))
      CPASSERT(IS_CONTIGUOUS(rab))
      CPASSERT(IS_CONTIGUOUS(npts_global))
      CPASSERT(IS_CONTIGUOUS(npts_local))
      CPASSERT(IS_CONTIGUOUS(shift_local))
      CPASSERT(IS_CONTIGUOUS(border_width))
      CPASSERT(IS_CONTIGUOUS(pab))
      CPASSERT(IS_CONTIGUOUS(grid))
#endif

      CALL grid_collocate_pgf_product_cpu(orthorhombic=orthorhombic, &
                                          border_mask=border_mask, &
                                          func=ga_gb_function, &
                                          la_max=la_max, &
                                          la_min=la_min, &
                                          lb_max=lb_max, &
                                          lb_min=lb_min, &
                                          zeta=zeta, &
                                          zetb=zetb, &
                                          rscale=scale, &
                                          dh=C_LOC(rsgrid%desc%dh(1, 1)), &
                                          dh_inv=C_LOC(rsgrid%desc%dh_inv(1, 1)), &
                                          ra=C_LOC(ra(1)), &
                                          rab=C_LOC(rab(1)), &
                                          npts_global=C_LOC(npts_global(1)), &
                                          npts_local=C_LOC(npts_local(1)), &
                                          shift_local=C_LOC(shift_local(1)), &
                                          border_width=C_LOC(border_width(1)), &
                                          radius=radius, &
                                          o1=o1, &
                                          o2=o2, &
                                          n1=SIZE(pab, 1), &
                                          n2=SIZE(pab, 2), &
                                          pab=C_LOC(pab(1, 1)), &
                                          grid=C_LOC(grid(1, 1, 1)))

      IF (validate_collocate) THEN
         CALL collocate_pgf_product_legacy(la_max, zeta, la_min, &
                                           lb_max, zetb, lb_min, &
                                           ra, rab, scale, pab, o1, o2, &
                                           rsgrid, cell, cube_info, &
                                           ga_gb_function, radius, &
                                           use_subpatch, subpatch_pattern)
         IF (orthorhombic .AND. border_mask == 0) THEN
            tolerance = 6e-14
         ELSE
            tolerance = 2e-10
         END IF
         counter = counter + 1
         my_pos = rsgrid%desc%my_pos
         DO i = 1, SIZE(rsgrid%r, 1)
         DO j = 1, SIZE(rsgrid%r, 2)
         DO k = 1, SIZE(rsgrid%r, 3)
            ref_value = rsgrid%r(i - 1 + LBOUND(rsgrid%r, 1), j - 1 + LBOUND(rsgrid%r, 2), k - 1 + LBOUND(rsgrid%r, 3))
            diff = ABS(grid(i, j, k) - ref_value)
            rel_diff = diff/MAX(1.0_dp, ABS(ref_value))
            !IF ((ref_value==0.0_dp) .NEQV. (grid(i, j, k)==0.0_dp)) THEN
            IF (rel_diff > tolerance) THEN
               iw = cp_logger_get_default_io_unit()
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "diff: ", diff
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "rel. diff: ", rel_diff
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "value:", grid(i, j, k), "ref_value:", ref_value
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "ijk:", i - 1, j - 1, k - 1
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "npts_global:", npts_global
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "npts_local:", npts_local
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "shift_local:", shift_local
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "orthorhombic:", orthorhombic
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "ga_gb_function:", ga_gb_function
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "border_mask:", border_mask
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "border_width:", border_width
               WRITE (iw, *) "counter: ", counter, "my_pos: ", my_pos, "distributed:", rsgrid%desc%distributed
               CPABORT("Collocate validation failed.")
            END IF
         ENDDO
         ENDDO
         ENDDO
         rsgrid%r = rsgrid%r + grid_before
         DEALLOCATE (grid, grid_before)
      ENDIF

   END SUBROUTINE collocate_pgf_product

! **************************************************************************************************
!> \brief Helper routines for getting rsgrid properties and asserting underlying assumptions.
!> \param rsgrid ...
!> \param npts_global ...
!> \param npts_local ...
!> \param shift_local ...
!> \param border_width ...
!> \author Ole Schuett
! **************************************************************************************************
   SUBROUTINE get_rsgrid_properties(rsgrid, npts_global, npts_local, shift_local, border_width)
      TYPE(realspace_grid_type), INTENT(IN)              :: rsgrid
      INTEGER, DIMENSION(:)                              :: npts_global, npts_local, shift_local, &
                                                            border_width

      INTEGER                                            :: i

      ! See rs_grid_create() in ./src/pw/realspace_grid_types.F.
      CPASSERT(LBOUND(rsgrid%r, 1) == rsgrid%lb_local(1))
      CPASSERT(UBOUND(rsgrid%r, 1) == rsgrid%ub_local(1))
      CPASSERT(LBOUND(rsgrid%r, 2) == rsgrid%lb_local(2))
      CPASSERT(UBOUND(rsgrid%r, 2) == rsgrid%ub_local(2))
      CPASSERT(LBOUND(rsgrid%r, 3) == rsgrid%lb_local(3))
      CPASSERT(UBOUND(rsgrid%r, 3) == rsgrid%ub_local(3))

      ! While the rsgrid code assumes that the grid starts at rsgrid%lb,
      ! the collocate code assumes that the grid starts at (1,1,1) in Fortran, or (0,0,0) in C.
      ! So, a point rp(:) gets the following grid coordinates MODULO(rp(:)/dr(:),npts_global(:))

      ! Number of global grid points in each direction.
      npts_global = rsgrid%desc%ub - rsgrid%desc%lb + 1

      ! Number of local grid points in each direction.
      npts_local = rsgrid%ub_local - rsgrid%lb_local + 1

      ! Number of points the local grid is shifted wrt global grid.
      shift_local = rsgrid%lb_local - rsgrid%desc%lb

      ! Convert rsgrid%desc%border and rsgrid%desc%perd into the more convenient border_width array.
      DO i = 1, 3
         IF (rsgrid%desc%perd(i) == 1) THEN
            ! Periodic meaning the grid in this direction is entriely present on every processor.
            CPASSERT(npts_local(i) == npts_global(i))
            CPASSERT(shift_local(i) == 0)
            ! No need for halo regions.
            border_width(i) = 0
         ELSE
            ! Not periodic meaning the grid in this direction is distributed among processors.
            CPASSERT(npts_local(i) <= npts_global(i))
            ! Check bounds of grid section that is owned by this processor.
            CPASSERT(rsgrid%lb_real(i) == rsgrid%lb_local(i) + rsgrid%desc%border)
            CPASSERT(rsgrid%ub_real(i) == rsgrid%ub_local(i) - rsgrid%desc%border)
            ! We have halo regions.
            border_width(i) = rsgrid%desc%border
         ENDIF
      ENDDO
   END SUBROUTINE get_rsgrid_properties

! **************************************************************************************************
!> \brief Allocates a basis set which can be passed to grid_create_task_list.
!> \param nset ...
!> \param nsgf ...
!> \param maxco ...
!> \param maxpgf ...
!> \param lmin ...
!> \param lmax ...
!> \param npgf ...
!> \param nsgf_set ...
!> \param first_sgf ...
!> \param sphi ...
!> \param zet ...
!> \param basis_set ...
!> \author Ole Schuett
! **************************************************************************************************
   SUBROUTINE grid_create_basis_set(nset, nsgf, maxco, maxpgf, &
                                    lmin, lmax, npgf, nsgf_set, first_sgf, sphi, zet, &
                                    basis_set)
      INTEGER, INTENT(IN)                                :: nset, nsgf, maxco, maxpgf
      INTEGER, DIMENSION(:), INTENT(IN), TARGET          :: lmin, lmax, npgf, nsgf_set
      INTEGER, DIMENSION(:, :), INTENT(IN)               :: first_sgf
      REAL(KIND=dp), DIMENSION(:, :), INTENT(IN), TARGET :: sphi, zet
      TYPE(grid_basis_set_type), INTENT(INOUT)           :: basis_set

      INTEGER, DIMENSION(nset), TARGET                   :: my_first_sgf
      TYPE(C_PTR)                                        :: first_sgf_c, lmax_c, lmin_c, npgf_c, &
                                                            nsgf_set_c, sphi_c, zet_c
      INTERFACE
         SUBROUTINE grid_create_basis_set_c(nset, nsgf, maxco, maxpgf, &
                                            lmin, lmax, npgf, nsgf_set, first_sgf, sphi, zet, &
                                            basis_set) &
            BIND(C, name="grid_create_basis_set")
            IMPORT :: C_PTR, C_INT
            INTEGER(KIND=C_INT), VALUE                :: nset
            INTEGER(KIND=C_INT), VALUE                :: nsgf
            INTEGER(KIND=C_INT), VALUE                :: maxco
            INTEGER(KIND=C_INT), VALUE                :: maxpgf
            TYPE(C_PTR), VALUE                        :: lmin
            TYPE(C_PTR), VALUE                        :: lmax
            TYPE(C_PTR), VALUE                        :: npgf
            TYPE(C_PTR), VALUE                        :: nsgf_set
            TYPE(C_PTR), VALUE                        :: first_sgf
            TYPE(C_PTR), VALUE                        :: sphi
            TYPE(C_PTR), VALUE                        :: zet
            TYPE(C_PTR)                               :: basis_set
         END SUBROUTINE grid_create_basis_set_c
      END INTERFACE

      CPASSERT(SIZE(lmin) == nset)
      CPASSERT(SIZE(lmin) == nset)
      CPASSERT(SIZE(lmax) == nset)
      CPASSERT(SIZE(npgf) == nset)
      CPASSERT(SIZE(nsgf_set) == nset)
      CPASSERT(SIZE(first_sgf, 2) == nset)
      CPASSERT(SIZE(sphi, 1) == maxco .AND. SIZE(sphi, 2) == nsgf)
      CPASSERT(SIZE(zet, 1) == maxpgf .AND. SIZE(zet, 2) == nset)
      CPASSERT(.NOT. C_ASSOCIATED(basis_set%c_ptr))

#if __GNUC__ >= 9
      CPASSERT(IS_CONTIGUOUS(lmin))
      CPASSERT(IS_CONTIGUOUS(lmax))
      CPASSERT(IS_CONTIGUOUS(npgf))
      CPASSERT(IS_CONTIGUOUS(nsgf_set))
      CPASSERT(IS_CONTIGUOUS(my_first_sgf))
      CPASSERT(IS_CONTIGUOUS(sphi))
      CPASSERT(IS_CONTIGUOUS(zet))
#endif

      lmin_c = C_NULL_PTR
      lmax_c = C_NULL_PTR
      npgf_c = C_NULL_PTR
      nsgf_set_c = C_NULL_PTR
      first_sgf_c = C_NULL_PTR
      sphi_c = C_NULL_PTR
      zet_c = C_NULL_PTR

      ! Basis sets arrays can be empty, need to check before accessing the first element.
      IF (nset > 0) THEN
         lmin_c = C_LOC(lmin(1))
         lmax_c = C_LOC(lmax(1))
         npgf_c = C_LOC(npgf(1))
         nsgf_set_c = C_LOC(nsgf_set(1))
      ENDIF
      IF (SIZE(first_sgf) > 0) THEN
         my_first_sgf(:) = first_sgf(1, :)  ! make a contiguous copy
         first_sgf_c = C_LOC(my_first_sgf(1))
      ENDIF
      IF (SIZE(sphi) > 0) THEN
         sphi_c = C_LOC(sphi(1, 1))
      ENDIF
      IF (SIZE(zet) > 0) THEN
         zet_c = C_LOC(zet(1, 1))
      ENDIF

      CALL grid_create_basis_set_c(nset=nset, &
                                   nsgf=nsgf, &
                                   maxco=maxco, &
                                   maxpgf=maxpgf, &
                                   lmin=lmin_c, &
                                   lmax=lmax_c, &
                                   npgf=npgf_c, &
                                   nsgf_set=nsgf_set_c, &
                                   first_sgf=first_sgf_c, &
                                   sphi=sphi_c, &
                                   zet=zet_c, &
                                   basis_set=basis_set%c_ptr)
      CPASSERT(C_ASSOCIATED(basis_set%c_ptr))

   END SUBROUTINE grid_create_basis_set

! **************************************************************************************************
!> \brief Deallocates given basis set.
!> \param basis_set ...
!> \author Ole Schuett
! **************************************************************************************************
   SUBROUTINE grid_free_basis_set(basis_set)
      TYPE(grid_basis_set_type), INTENT(INOUT)           :: basis_set

      INTERFACE
         SUBROUTINE grid_free_basis_set_c(basis_set) &
            BIND(C, name="grid_free_basis_set")
            IMPORT :: C_PTR
            TYPE(C_PTR), VALUE                        :: basis_set
         END SUBROUTINE grid_free_basis_set_c
      END INTERFACE

      CPASSERT(C_ASSOCIATED(basis_set%c_ptr))

      CALL grid_free_basis_set_c(basis_set%c_ptr)

      basis_set%c_ptr = C_NULL_PTR

   END SUBROUTINE grid_free_basis_set

! **************************************************************************************************
!> \brief Allocates a task list which can be passed to grid_collocate_task_list.
!> \param ntasks ...
!> \param nlevels ...
!> \param natoms ...
!> \param nkinds ...
!> \param nblocks ...
!> \param buffer_size ...
!> \param block_offsets ...
!> \param atom_positions ...
!> \param atom_kinds ...
!> \param basis_sets ...
!> \param level_list ...
!> \param iatom_list ...
!> \param jatom_list ...
!> \param iset_list ...
!> \param jset_list ...
!> \param ipgf_list ...
!> \param jpgf_list ...
!> \param border_mask_list ...
!> \param block_num_list ...
!> \param radius_list ...
!> \param rab_list ...
!> \param blocks_buffer ...
!> \param task_list ...
!> \author Ole Schuett
! **************************************************************************************************
   SUBROUTINE grid_create_task_list(ntasks, nlevels, natoms, nkinds, nblocks, buffer_size, &
                                    block_offsets, atom_positions, atom_kinds, basis_sets, &
                                    level_list, iatom_list, jatom_list, &
                                    iset_list, jset_list, ipgf_list, jpgf_list, &
                                    border_mask_list, block_num_list, &
                                    radius_list, rab_list, blocks_buffer, task_list)

      INTEGER, INTENT(IN)                                :: ntasks, nlevels, natoms, nkinds, &
                                                            nblocks, buffer_size
      INTEGER, DIMENSION(:), INTENT(IN), TARGET          :: block_offsets
      REAL(KIND=dp), DIMENSION(:, :), INTENT(IN), TARGET :: atom_positions
      INTEGER, DIMENSION(:), INTENT(IN), TARGET          :: atom_kinds
      TYPE(grid_basis_set_type), DIMENSION(:), &
         INTENT(IN), TARGET                              :: basis_sets
      INTEGER, DIMENSION(:), INTENT(IN), TARGET          :: level_list, iatom_list, jatom_list, &
                                                            iset_list, jset_list, ipgf_list, &
                                                            jpgf_list, border_mask_list, &
                                                            block_num_list
      REAL(KIND=dp), DIMENSION(:), INTENT(IN), TARGET    :: radius_list
      REAL(KIND=dp), DIMENSION(:, :), INTENT(IN), TARGET :: rab_list
      REAL(KIND=dp), DIMENSION(:), INTENT(OUT), POINTER  :: blocks_buffer
      TYPE(grid_task_list_type), INTENT(INOUT)           :: task_list

      INTEGER                                            :: ikind
      TYPE(C_PTR)                                        :: blocks_buffer_c
      TYPE(C_PTR), ALLOCATABLE, DIMENSION(:), TARGET     :: basis_sets_c
      INTERFACE
         SUBROUTINE grid_create_task_list_c(ntasks, nlevels, natoms, nkinds, nblocks, buffer_size, &
                                            block_offsets, atom_positions, atom_kinds, basis_sets, &
                                            level_list, iatom_list, jatom_list, &
                                            iset_list, jset_list, ipgf_list, jpgf_list, &
                                            border_mask_list, block_num_list, &
                                            radius_list, rab_list, blocks_buffer, task_list) &
            BIND(C, name="grid_create_task_list")
            IMPORT :: C_PTR, C_INT
            INTEGER(KIND=C_INT), VALUE                :: ntasks
            INTEGER(KIND=C_INT), VALUE                :: nlevels
            INTEGER(KIND=C_INT), VALUE                :: natoms
            INTEGER(KIND=C_INT), VALUE                :: nkinds
            INTEGER(KIND=C_INT), VALUE                :: nblocks
            INTEGER(KIND=C_INT), VALUE                :: buffer_size
            TYPE(C_PTR), VALUE                        :: block_offsets
            TYPE(C_PTR), VALUE                        :: atom_positions
            TYPE(C_PTR), VALUE                        :: atom_kinds
            TYPE(C_PTR), VALUE                        :: basis_sets
            TYPE(C_PTR), VALUE                        :: level_list
            TYPE(C_PTR), VALUE                        :: iatom_list
            TYPE(C_PTR), VALUE                        :: jatom_list
            TYPE(C_PTR), VALUE                        :: iset_list
            TYPE(C_PTR), VALUE                        :: jset_list
            TYPE(C_PTR), VALUE                        :: ipgf_list
            TYPE(C_PTR), VALUE                        :: jpgf_list
            TYPE(C_PTR), VALUE                        :: border_mask_list
            TYPE(C_PTR), VALUE                        :: block_num_list
            TYPE(C_PTR), VALUE                        :: radius_list
            TYPE(C_PTR), VALUE                        :: rab_list
            TYPE(C_PTR)                               :: blocks_buffer
            TYPE(C_PTR)                               :: task_list
         END SUBROUTINE grid_create_task_list_c
      END INTERFACE

      CPASSERT(SIZE(block_offsets) == nblocks)
      CPASSERT(SIZE(atom_positions, 1) == 3 .AND. SIZE(atom_positions, 2) == natoms)
      CPASSERT(SIZE(atom_kinds) == natoms)
      CPASSERT(SIZE(basis_sets) == nkinds)
      CPASSERT(SIZE(level_list) == ntasks)
      CPASSERT(SIZE(iatom_list) == ntasks)
      CPASSERT(SIZE(jatom_list) == ntasks)
      CPASSERT(SIZE(iset_list) == ntasks)
      CPASSERT(SIZE(jset_list) == ntasks)
      CPASSERT(SIZE(ipgf_list) == ntasks)
      CPASSERT(SIZE(jpgf_list) == ntasks)
      CPASSERT(SIZE(border_mask_list) == ntasks)
      CPASSERT(SIZE(block_num_list) == ntasks)
      CPASSERT(SIZE(radius_list) == ntasks)
      CPASSERT(SIZE(rab_list, 1) == 3 .AND. SIZE(rab_list, 2) == ntasks)

      ALLOCATE (basis_sets_c(nkinds))
      DO ikind = 1, nkinds
         basis_sets_c(ikind) = basis_sets(ikind)%c_ptr
      END DO

#if __GNUC__ >= 9
      CPASSERT(IS_CONTIGUOUS(block_offsets))
      CPASSERT(IS_CONTIGUOUS(atom_positions))
      CPASSERT(IS_CONTIGUOUS(atom_kinds))
      CPASSERT(IS_CONTIGUOUS(basis_sets))
      CPASSERT(IS_CONTIGUOUS(level_list))
      CPASSERT(IS_CONTIGUOUS(iatom_list))
      CPASSERT(IS_CONTIGUOUS(jatom_list))
      CPASSERT(IS_CONTIGUOUS(iset_list))
      CPASSERT(IS_CONTIGUOUS(jset_list))
      CPASSERT(IS_CONTIGUOUS(ipgf_list))
      CPASSERT(IS_CONTIGUOUS(jpgf_list))
      CPASSERT(IS_CONTIGUOUS(border_mask_list))
      CPASSERT(IS_CONTIGUOUS(block_num_list))
      CPASSERT(IS_CONTIGUOUS(radius_list))
      CPASSERT(IS_CONTIGUOUS(rab_list))
#endif

      !If task_list%c_ptr is already allocated, then its memory will be reused or freed.
      blocks_buffer_c = C_NULL_PTR
      IF (ntasks == 0) THEN
         CALL grid_create_task_list_c(0, nlevels, 0, 0, 0, 0, C_NULL_PTR, C_NULL_PTR, C_NULL_PTR, &
                                      C_NULL_PTR, C_NULL_PTR, C_NULL_PTR, C_NULL_PTR, C_NULL_PTR, &
                                      C_NULL_PTR, C_NULL_PTR, C_NULL_PTR, C_NULL_PTR, C_NULL_PTR, &
                                      C_NULL_PTR, C_NULL_PTR, &
                                      blocks_buffer=blocks_buffer_c, &
                                      task_list=task_list%c_ptr)
      ELSE
         CALL grid_create_task_list_c(ntasks=ntasks, &
                                      nlevels=nlevels, &
                                      natoms=natoms, &
                                      nkinds=nkinds, &
                                      nblocks=nblocks, &
                                      buffer_size=buffer_size, &
                                      block_offsets=C_LOC(block_offsets(1)), &
                                      atom_positions=C_LOC(atom_positions(1, 1)), &
                                      atom_kinds=C_LOC(atom_kinds(1)), &
                                      basis_sets=C_LOC(basis_sets_c(1)), &
                                      level_list=C_LOC(level_list(1)), &
                                      iatom_list=C_LOC(iatom_list(1)), &
                                      jatom_list=C_LOC(jatom_list(1)), &
                                      iset_list=C_LOC(iset_list(1)), &
                                      jset_list=C_LOC(jset_list(1)), &
                                      ipgf_list=C_LOC(ipgf_list(1)), &
                                      jpgf_list=C_LOC(jpgf_list(1)), &
                                      border_mask_list=C_LOC(border_mask_list(1)), &
                                      block_num_list=C_LOC(block_num_list(1)), &
                                      radius_list=C_LOC(radius_list(1)), &
                                      rab_list=C_LOC(rab_list(1, 1)), &
                                      blocks_buffer=blocks_buffer_c, &
                                      task_list=task_list%c_ptr)
         CPASSERT(C_ASSOCIATED(blocks_buffer_c))
      ENDIF

      CPASSERT(C_ASSOCIATED(task_list%c_ptr))
      CALL C_F_POINTER(blocks_buffer_c, blocks_buffer, shape=(/buffer_size/))

   END SUBROUTINE grid_create_task_list

! **************************************************************************************************
!> \brief Deallocates given task list, basis_sets have to be freed separately.
!> \param task_list ...
!> \author Ole Schuett
! **************************************************************************************************
   SUBROUTINE grid_free_task_list(task_list)
      TYPE(grid_task_list_type), INTENT(INOUT)           :: task_list

      INTERFACE
         SUBROUTINE grid_free_task_list_c(task_list) &
            BIND(C, name="grid_free_task_list")
            IMPORT :: C_PTR
            TYPE(C_PTR), VALUE                        :: task_list
         END SUBROUTINE grid_free_task_list_c
      END INTERFACE

      IF (C_ASSOCIATED(task_list%c_ptr)) THEN
         CALL grid_free_task_list_c(task_list%c_ptr)
      ENDIF

      task_list%c_ptr = C_NULL_PTR

   END SUBROUTINE grid_free_task_list

! **************************************************************************************************
!> \brief Collocate all tasks of in given list onto given grids.
!> \param task_list ...
!> \param ga_gb_function ...
!> \param rs_grids ...
!> \author Ole Schuett
! **************************************************************************************************
   SUBROUTINE grid_collocate_task_list(task_list, ga_gb_function, rs_grids)
      TYPE(grid_task_list_type), INTENT(IN)              :: task_list
      INTEGER, INTENT(IN)                                :: ga_gb_function
      TYPE(realspace_grid_p_type), DIMENSION(:), POINTER :: rs_grids

      INTEGER                                            :: ilevel, nlevels
      INTEGER, ALLOCATABLE, DIMENSION(:, :), TARGET      :: border_width, npts_global, npts_local, &
                                                            shift_local
      LOGICAL(KIND=C_BOOL)                               :: orthorhombic
      REAL(KIND=dp), ALLOCATABLE, DIMENSION(:, :, :), &
         TARGET                                          :: dh, dh_inv
      REAL(KIND=dp), DIMENSION(:, :, :), POINTER         :: grid
      TYPE(C_PTR), ALLOCATABLE, DIMENSION(:), TARGET     :: grid_pointers
      TYPE(realspace_grid_type), POINTER                 :: rsgrid
      INTERFACE
         SUBROUTINE grid_collocate_task_list_c(task_list, orthorhombic, func, nlevels, &
                                               npts_global, npts_local, shift_local, &
                                               border_width, dh, dh_inv, grid) &
            BIND(C, name="grid_collocate_task_list")
            IMPORT :: C_PTR, C_INT, C_BOOL
            TYPE(C_PTR), VALUE                        :: task_list
            LOGICAL(KIND=C_BOOL), VALUE               :: orthorhombic
            INTEGER(KIND=C_INT), VALUE                :: func
            INTEGER(KIND=C_INT), VALUE                :: nlevels
            TYPE(C_PTR), VALUE                        :: npts_global
            TYPE(C_PTR), VALUE                        :: npts_local
            TYPE(C_PTR), VALUE                        :: shift_local
            TYPE(C_PTR), VALUE                        :: border_width
            TYPE(C_PTR), VALUE                        :: dh
            TYPE(C_PTR), VALUE                        :: dh_inv
            TYPE(C_PTR), VALUE                        :: grid
         END SUBROUTINE grid_collocate_task_list_c
      END INTERFACE

      nlevels = SIZE(rs_grids)
      CPASSERT(nlevels > 0)
      orthorhombic = LOGICAL(rs_grids(1)%rs_grid%desc%orthorhombic, C_BOOL)

      ALLOCATE (grid_pointers(nlevels))
      ALLOCATE (npts_global(3, nlevels), npts_local(3, nlevels))
      ALLOCATE (shift_local(3, nlevels), border_width(3, nlevels))
      ALLOCATE (dh(3, 3, nlevels), dh_inv(3, 3, nlevels))
      DO ilevel = 1, nlevels
         rsgrid => rs_grids(ilevel)%rs_grid
         CALL get_rsgrid_properties(rsgrid=rsgrid, &
                                    npts_global=npts_global(:, ilevel), &
                                    npts_local=npts_local(:, ilevel), &
                                    shift_local=shift_local(:, ilevel), &
                                    border_width=border_width(:, ilevel))
         CPASSERT(rsgrid%desc%orthorhombic .EQV. orthorhombic)  ! should be the same for all levels
         dh(:, :, ilevel) = rsgrid%desc%dh(:, :)
         dh_inv(:, :, ilevel) = rsgrid%desc%dh_inv(:, :)
         grid(1:, 1:, 1:) => rsgrid%r(:, :, :)  ! ensure lower bounds are (1,1,1)
         grid_pointers(ilevel) = C_LOC(grid(1, 1, 1))
      END DO

#if __GNUC__ >= 9
      CPASSERT(IS_CONTIGUOUS(npts_global))
      CPASSERT(IS_CONTIGUOUS(npts_local))
      CPASSERT(IS_CONTIGUOUS(shift_local))
      CPASSERT(IS_CONTIGUOUS(border_width))
      CPASSERT(IS_CONTIGUOUS(dh))
      CPASSERT(IS_CONTIGUOUS(dh_inv))
      CPASSERT(IS_CONTIGUOUS(grid_pointers))
      DO ilevel = 1, nlevels
         grid(1:, 1:, 1:) => rs_grids(ilevel)%rs_grid%r(:, :, :)
         CPASSERT(IS_CONTIGUOUS(grid))
      END DO
#endif

      CPASSERT(C_ASSOCIATED(task_list%c_ptr))

      CALL grid_collocate_task_list_c(task_list=task_list%c_ptr, &
                                      orthorhombic=orthorhombic, &
                                      func=ga_gb_function, &
                                      nlevels=nlevels, &
                                      npts_global=C_LOC(npts_global(1, 1)), &
                                      npts_local=C_LOC(npts_local(1, 1)), &
                                      shift_local=C_LOC(shift_local(1, 1)), &
                                      border_width=C_LOC(border_width(1, 1)), &
                                      dh=C_LOC(dh(1, 1, 1)), &
                                      dh_inv=C_LOC(dh_inv(1, 1, 1)), &
                                      grid=C_LOC(grid_pointers(1)))

   END SUBROUTINE grid_collocate_task_list

END MODULE grid_api

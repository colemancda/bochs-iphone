/////////////////////////////////////////////////////////////////////////
// $Id: rombios32start.S,v 1.9 2009/01/26 09:21:00 vruppert Exp $
/////////////////////////////////////////////////////////////////////////
//
//  32 bit Bochs BIOS init code
//  Copyright (C) 2006 Fabrice Bellard
//
//  This library is free software; you can redistribute it and/or
//  modify it under the terms of the GNU Lesser General Public
//  License as published by the Free Software Foundation; either
//  version 2 of the License, or (at your option) any later version.
//
//  This library is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
//  Lesser General Public License for more details.
//
//  You should have received a copy of the GNU Lesser General Public
//  License along with this library; if not, write to the Free Software
//  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301 USA
#include "rombios.h"

.globl _start
.globl smp_ap_boot_code_start
.globl smp_ap_boot_code_end
.global smm_relocation_start
.global smm_relocation_end
.global smm_code_start
.global smm_code_end

_start:
  /* clear bss section */
  xor %eax, %eax
  mov $__bss_start, %edi
  mov $__bss_end, %ecx
  sub %edi, %ecx
  rep stosb

  /* copy data section */
  mov $_end, %esi
  mov $__data_start, %edi
  mov $__data_end, %ecx
  sub %edi, %ecx
  rep movsb

  jmp rombios32_init

  .code16
smp_ap_boot_code_start:
  cli
  xor %ax, %ax
  mov %ax, %ds

  mov $SMP_MSR_ADDR, %ebx
11:
  mov 0(%ebx), %ecx
  test %ecx, %ecx
  jz 12f
  mov 4(%ebx), %eax
  mov 8(%ebx), %edx
  wrmsr
  add $12, %ebx
  jmp 11b
12:

  lock incw smp_cpus
1:
  hlt
  jmp 1b
smp_ap_boot_code_end:

/* code to relocate SMBASE to 0xa0000 */
smm_relocation_start:
  mov $0x38000 + 0x7efc, %ebx
  addr32 mov (%ebx), %al  /* revision ID to see if x86_64 or x86 */
  cmp $0x64, %al
  je 1f
  mov $0x38000 + 0x7ef8, %ebx
  jmp 2f
1:
  mov $0x38000 + 0x7f00, %ebx
2:
  movl $0xa0000, %eax
  addr32 movl %eax, (%ebx)
  /* indicate to the BIOS that the SMM code was executed */
  mov $0x00, %al
  movw $0xb3, %dx
  outb %al, %dx
  rsm
smm_relocation_end:

/* minimal SMM code to enable or disable ACPI */
smm_code_start:
  movw $0xb2, %dx
  inb %dx, %al
  cmp $0xf0, %al
  jne 1f

  /* ACPI disable */
  mov $PM_IO_BASE + 0x04, %dx /* PMCNTRL */
  inw %dx, %ax
  andw $~1, %ax
  outw %ax, %dx

  jmp 2f

1:
  cmp $0xf1, %al
  jne 2f

  /* ACPI enable */
  mov $PM_IO_BASE + 0x04, %dx /* PMCNTRL */
  inw %dx, %ax
  orw $1, %ax
  outw %ax, %dx

2:
  rsm
smm_code_end:

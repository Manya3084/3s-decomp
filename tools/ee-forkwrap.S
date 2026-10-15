/* EE GCC 2.96 calls fork() with a 4-byte aligned stack.
   glibc 2.41+ i386 fork() crashes on that alignment.
   Raw int $0x80 keeps the driver alive on current Arch. */
	.text
	.globl fork
	.type fork, @function
fork:
	push %ebx
	mov $2, %eax
	int $0x80
	pop %ebx
	ret

	.globl vfork
	.type vfork, @function
vfork:
	push %ebx
	mov $190, %eax
	int $0x80
	pop %ebx
	ret

	.globl __vfork
	.type __vfork, @function
__vfork:
	jmp vfork

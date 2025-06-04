extern "C" {
    void start(void);      // your ASM init routine
    void loop_asm(void);   // your ASM loop body (should return so Arduino can call it again)
}

void setup() {
    // call your ASM startup (I/O and timer init)
    start();
}

void loop() {
    // delegate main work to your ASM loop
    loop_asm();
}
